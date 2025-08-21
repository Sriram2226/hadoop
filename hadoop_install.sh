#!/bin/bash
# Hadoop Installation Automation Script
# Tested for Ubuntu-based systems

HADOOP_VERSION="2.6.5"
HADOOP_HOME="/usr/local/hadoop"
HADOOP_USER="hduser"
HADOOP_GROUP="hadoop"

echo "=== Step 1: Removing APT Locks ==="
sudo rm -f /var/lib/apt/lists/lock
sudo rm -f /var/cache/apt/archives/lock
sudo rm -f /var/lib/dpkg/lock
sudo rm -f /var/lib/dpkg/lock-frontend

echo "=== Step 2: Installing Java ==="
sudo apt-get update -y
sudo apt-get install -y openjdk-8-jdk ssh wget tar

echo "=== Step 3: Adding Hadoop Group and User ==="
sudo addgroup $HADOOP_GROUP
sudo adduser --ingroup $HADOOP_GROUP $HADOOP_USER --disabled-password --gecos ""

echo "=== Step 4: Setting up SSH for $HADOOP_USER ==="
sudo -u $HADOOP_USER ssh-keygen -t rsa -P "" -f /home/$HADOOP_USER/.ssh/id_rsa
cat /home/$HADOOP_USER/.ssh/id_rsa.pub | sudo tee -a /home/$HADOOP_USER/.ssh/authorized_keys
sudo chown -R $HADOOP_USER:$HADOOP_GROUP /home/$HADOOP_USER/.ssh
sudo chmod 600 /home/$HADOOP_USER/.ssh/authorized_keys

echo "=== Step 5: Downloading and Installing Hadoop ==="
mkdir -p /home/$HADOOP_USER/mapreduce/software
cd /home/$HADOOP_USER/mapreduce/software
wget -q https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz
tar -xvzf hadoop-${HADOOP_VERSION}.tar.gz
sudo mkdir -p $HADOOP_HOME
sudo mv hadoop-${HADOOP_VERSION}/* $HADOOP_HOME
sudo chown -R $HADOOP_USER:$HADOOP_GROUP $HADOOP_HOME

echo "=== Step 6: Configuring Hadoop Environment Variables ==="
cat <<EOF | sudo tee -a /home/$HADOOP_USER/.bashrc
# HADOOP VARIABLES START
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_INSTALL=$HADOOP_HOME
export PATH=\$PATH:\$HADOOP_INSTALL/bin:\$HADOOP_INSTALL/sbin
export HADOOP_MAPRED_HOME=\$HADOOP_INSTALL
export HADOOP_COMMON_HOME=\$HADOOP_INSTALL
export HADOOP_HDFS_HOME=\$HADOOP_INSTALL
export YARN_HOME=\$HADOOP_INSTALL
export HADOOP_COMMON_LIB_NATIVE_DIR=\$HADOOP_INSTALL/lib/native
export HADOOP_OPTS="-Djava.library.path=\$HADOOP_INSTALL/lib"
export HADOOP_CLASSPATH=\$(hadoop classpath)
# HADOOP VARIABLES END
EOF

source /home/$HADOOP_USER/.bashrc

echo "=== Step 6.2: Updating hadoop-env.sh ==="
echo "export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64" | sudo tee -a $HADOOP_HOME/etc/hadoop/hadoop-env.sh

echo "=== Step 6.3: Creating temp directories ==="
sudo mkdir -p /app/hadoop/tmp
sudo chown -R $HADOOP_USER:$HADOOP_GROUP /app/hadoop/tmp

echo "=== Step 6.4: Configuring core-site.xml ==="
cat <<EOF | sudo tee $HADOOP_HOME/etc/hadoop/core-site.xml
<configuration>
 <property>
   <name>hadoop.tmp.dir</name>
   <value>/app/hadoop/tmp</value>
   <description>A base for other temporary directories.</description>
 </property>
 <property>
   <name>fs.default.name</name>
   <value>hdfs://localhost:54310</value>
 </property>
</configuration>
EOF

echo "=== Step 6.5: Configuring mapred-site.xml ==="
cp $HADOOP_HOME/etc/hadoop/mapred-site.xml.template $HADOOP_HOME/etc/hadoop/mapred-site.xml
cat <<EOF | sudo tee $HADOOP_HOME/etc/hadoop/mapred-site.xml
<configuration>
 <property>
   <name>mapred.job.tracker</name>
   <value>localhost:54311</value>
 </property>
 <property>
   <name>mapreduce.framework.name</name>
   <value>yarn</value>
 </property>
</configuration>
EOF

echo "=== Step 6.6: Creating HDFS directories ==="
sudo mkdir -p /usr/local/hadoop_store/hdfs/namenode
sudo mkdir -p /usr/local/hadoop_store/hdfs/datanode
sudo chown -R $HADOOP_USER:$HADOOP_GROUP /usr/local/hadoop_store

echo "=== Step 6.7: Configuring hdfs-site.xml ==="
cat <<EOF | sudo tee $HADOOP_HOME/etc/hadoop/hdfs-site.xml
<configuration>
 <property>
   <name>dfs.replication</name>
   <value>1</value>
 </property>
 <property>
   <name>dfs.namenode.name.dir</name>
   <value>file:/usr/local/hadoop_store/hdfs/namenode</value>
 </property>
 <property>
   <name>dfs.datanode.data.dir</name>
   <value>file:/usr/local/hadoop_store/hdfs/datanode</value>
 </property>
</configuration>
EOF

echo "=== Step 6.8: Formatting Namenode ==="
sudo -u $HADOOP_USER $HADOOP_HOME/bin/hdfs namenode -format

echo "=== Step 6.9: Configuring yarn-site.xml ==="
cat <<EOF | sudo tee $HADOOP_HOME/etc/hadoop/yarn-site.xml
<configuration>
 <property>
   <name>yarn.nodemanager.aux-services</name>
   <value>mapreduce_shuffle</value>
 </property>
 <property>
   <name>yarn.nodemanager.aux-services.mapreduce_shuffle.class</name>
   <value>org.apache.hadoop.mapred.ShuffleHandler</value>
 </property>
</configuration>
EOF

echo "=== Hadoop Installation Complete ==="
echo "To start Hadoop, run:"
echo " start-dfs.sh && start-yarn.sh "
