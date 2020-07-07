#!/bin/sh -xe

OS_VERSION=$1
XRD_CACHE=$2
PYTHON_VERSION=$3

ls -l /home

# Clean the yum cache
yum -y clean all
yum -y clean expire-cache

# First, install all the needed packages.
rpm -Uvh https://dl.fedoraproject.org/pub/epel/epel-release-latest-${OS_VERSION}.noarch.rpm

yum -y install yum-plugin-priorities
case $OS_VERSION in
    6) OSG_VERSION=3.4
        ;;
    7|8) OSG_VERSION=3.5
        ;;
esac
rpm -Uvh https://repo.opensciencegrid.org/osg/${OSG_VERSION}/osg-${OSG_VERSION}-el${OS_VERSION}-release-latest.rpm

yum -y install osg-oasis 


case $PYTHON_VERSION in
    2)
        pip=pip2
        python=python2
        if [ "$OS_VERSION" -eq 6 ]; then
            yum -y install python-setuptools
            easy_install 'pip < 10.0'
        else
            yum -y install python2-pip
        fi
        ;;
    3)
        yum -y install python3-pip
        pip=pip3
        python=python3
        ;;
esac

echo "user_allow_other" >> /etc/fuse.conf

echo "CVMFS_HTTP_PROXY=DIRECT" >> /etc/cvmfs/default.local
#echo "CVMFS_EXTERNAL_URL=$CVMFS_EXTERNAL_URL" >> /etc/cvmfs/domain.d/osgstorage.org.local

mkdir -p /cvmfs/config-osg.opensciencegrid.org
mkdir -p /cvmfs/oasis.opensciencegrid.org

mount -t cvmfs config-osg.opensciencegrid.org /cvmfs/config-osg.opensciencegrid.org
mount -t cvmfs oasis.opensciencegrid.org /cvmfs/oasis.opensciencegrid.org

# Load modules
set +e
. /cvmfs/oasis.opensciencegrid.org/osg/modules/lmod/current/init/bash 
set -e
module load xrootd

# For now, disable pylint failures
#pylint /StashCache/bin/stashcp || /bin/true

# Install stashcp
$pip install StashCache/

# Copy in the .job.ad file:
cp /StashCache/bin/stashcp2/tests/job.ad ./.job.ad

# Test against a file that is known to not exist
set +e
stashcp --cache=$XRD_CACHE /blah/does/not/exist ./
if [ $? -eq 0 ]; then
  echo "Failed to exit with non-zero exit status when it should have"
  exit 1
fi
set -e

# Try copying with no forward slash
stashcp --cache=$XRD_CACHE osgconnect/public/dweitzel/blast/queries/query1 ./

result=`md5sum query1 | awk '{print $1;}'`

rm query1

# Try copying with different destintion filename
stashcp --cache=$XRD_CACHE -d /osgconnect/public/dweitzel/blast/queries/query1 query.test

result=`md5sum query.test | awk '{print $1;}'`

if [ "$result" != "12bdb9a96cd5e8ca469b727a81593201" ]; then
  exit 1
fi

rm -f query.test

# Perform tests
stashcp --cache=$XRD_CACHE -d /osgconnect/public/dweitzel/blast/queries/query1 ./

result=`md5sum query1 | awk '{print $1;}'`

if [ "$result" != "12bdb9a96cd5e8ca469b727a81593201" ]; then
  exit 1
fi
rm -f query.test

# Perform methods test
stashcp --cache=$XRD_CACHE --method=cvmfs,xrootd -d /osgconnect/public/dweitzel/blast/queries/query1 ./

result=`md5sum query1 | awk '{print $1;}'`

if [ "$result" != "12bdb9a96cd5e8ca469b727a81593201" ]; then
  exit 1
fi
rm -f query.test

# Perform methods test
stashcp --cache=$XRD_CACHE --method=xrootd -d /osgconnect/public/dweitzel//blast/queries/query1 ./

result=`md5sum query1 | awk '{print $1;}'`

if [ "$result" != "12bdb9a96cd5e8ca469b727a81593201" ]; then
  exit 1
fi
rm -f query.test

# Perform methods test
stashcp --cache=$XRD_CACHE --method=http,xrootd -d /osgconnect/public/dweitzel/blast/queries/query1 ./

result=`md5sum query1 | awk '{print $1;}'`

if [ "$result" != "12bdb9a96cd5e8ca469b727a81593201" ]; then
  exit 1
fi
rm -f query.test

# Scheme test
stashcp --cache=$XRD_CACHE --method=http,xrootd -d stash:///osgconnect/public/dweitzel/blast/queries/query1 file:///tmp

result=`md5sum /tmp/query1 | awk '{print $1;}'`

if [ "$result" != "12bdb9a96cd5e8ca469b727a81593201" ]; then
  exit 1
fi
rm -f query.test

stashcp --cache=$XRD_CACHE -d -r /osgconnect/public/dweitzel/blast/queries ./
ls -lah

rm -rf queries

# Remove xenon tests as they have been failing consistently, and unable to reach
# maintainers that asked for the test in the first place
#/StashCache/bin/stashcp --cache=$XRD_CACHE -d /xenon/rucio/x1t_SR001_170419_1605_mv/73/90/XENON1T-0-000008000-000008999-000001000.zip ./
#result=`md5sum XENON1T-0-000008000-000008999-000001000.zip | awk '{print $1;}'`
#if [ "$result" != "dd00dd6a6b1e0de4a3b8ecf1a34b24b3" ]; then
#  exit 1
#fi




