#!/bin/bash
# Hadoop Single Node Cluster Automation Script
# Tested on Ubuntu (adjust paths if needed)

HADOOP_VERSION="2.6.5"
HADOOP_HOME="/usr/local/hadoop"
HADOOP_STORE="/usr/local/hadoop_store"
HADOOP_URL="https://archive.apache.org/dist/hadoop/common/hadoop-$HADOOP_VERSION/hadoop-$HADOOP_VERSION.tar.gz"
JAVA_HOME_PATH="/usr/lib/jvm/java-8-openjdk-amd64"

echo "=== Step 1: Removing apt locks ==="
sudo rm -f /var/lib/apt/lists/lock
sudo rm -f /var/cache/apt/archives/lock
sudo rm -f /var/lib/dpkg/lock
sudo rm -f /var/lib/dpkg/lock-frontend

echo "=== Step 2: Installing Java ==="
sudo apt-get update -y
sudo apt-get install -y openjdk-8-jdk ssh rsync wget tar

echo "Java version:"
java -version

echo "=== Step 3: Creating Hadoop group and user ==="
sudo addgroup hadoop
sudo adduser --ingroup hadoop hduser
echo "Set password for hduser:"
sudo passwd hduser
sudo usermod -aG sudo hduser

echo "=== Step 4: SSH setup for hduser ==="
sudo -u hduser ssh-keygen -t rsa -P "" -f /home/hduser/.ssh/id_rsa
sudo -u hduser sh -c 'cat /home/hduser/.ssh/id_rsa.pub >> /home/hduser/.ssh/authorized_keys'

echo "=== Step 5: Downloading and Installing Hadoop ==="
mkdir -p ~/mapreduce/software
cd ~/mapreduce/software
wget $HADOOP_URL
tar xvzf hadoop-$HADOOP_VERSION.tar.gz
sudo mkdir -p $HADOOP_HOME
cd hadoop-$HADOOP_VERSION
sudo mv * $HADOOP_HOME
sudo chown -R hduser:hadoop $HADOOP_HOME

echo "=== Step 6: Configuring Hadoop ==="
# Add environment variables to .bashrc
cat <<EOL >> /home/hduser/.bashrc

# HADOOP VARIABLES START
export JAVA_HOME=$JAVA_HOME_PATH
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
EOL

# Configure hadoop-env.sh
echo "export JAVA_HOME=$JAVA_HOME_PATH" | sudo tee -a $HADOOP_HOME/etc/hadoop/hadoop-env.sh

# Create tmp dir
sudo mkdir -p /app/hadoop/tmp
sudo chown hduser:hadoop /app/hadoop/tmp

# core-site.xml
cat <<EOL | sudo tee $HADOOP_HOME/etc/hadoop/core-site.xml
<configuration>
  <property>
    <name>hadoop.tmp.dir</name>
    <value>/app/hadoop/tmp</value>
  </property>
  <property>
    <name>fs.default.name</name>
    <value>hdfs://localhost:54310</value>
  </property>
</configuration>
EOL

# mapred-site.xml
sudo cp $HADOOP_HOME/etc/hadoop/mapred-site.xml.template $HADOOP_HOME/etc/hadoop/mapred-site.xml
cat <<EOL | sudo tee $HADOOP_HOME/etc/hadoop/mapred-site.xml
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
EOL

# hdfs-site.xml
sudo mkdir -p $HADOOP_STORE/hdfs/namenode
sudo mkdir -p $HADOOP_STORE/hdfs/datanode
sudo chown -R hduser:hadoop $HADOOP_STORE

cat <<EOL | sudo tee $HADOOP_HOME/etc/hadoop/hdfs-site.xml
<configuration>
  <property>
    <name>dfs.replication</name>
    <value>1</value>
  </property>
  <property>
    <name>dfs.namenode.name.dir</name>
    <value>file:$HADOOP_STORE/hdfs/namenode</value>
  </property>
  <property>
    <name>dfs.datanode.data.dir</name>
    <value>file:$HADOOP_STORE/hdfs/datanode</value>
  </property>
</configuration>
EOL

# yarn-site.xml
cat <<EOL | sudo tee $HADOOP_HOME/etc/hadoop/yarn-site.xml
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
EOL

echo "=== Step 7: Formatting Hadoop filesystem ==="
sudo -u hduser $HADOOP_HOME/bin/hadoop namenode -format

echo "=== Setup complete. Use following commands as hduser ==="
echo "Start Hadoop: start-all.sh"
echo "Stop Hadoop: stop-all.sh"
echo "Check daemons: jps"
