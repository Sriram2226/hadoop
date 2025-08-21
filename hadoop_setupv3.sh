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
if ! getent group $HADOOP_GROUP >/dev/null; then
  sudo addgroup $HADOOP_GROUP
fi
if ! id -u $HADOOP_USER >/dev/null 2>&1; then
  sudo adduser --ingroup $HADOOP_GROUP $HADOOP_USER --disabled-password --gecos ""
fi

echo "=== Step 4: Setting up SSH for $HADOOP_USER ==="
sudo -u $HADOOP_USER ssh-keygen -t rsa -P "" -f /home/$HADOOP_USER/.ssh/id_rsa
sudo -u $HADOOP_USER bash -c "cat /home/$HADOOP_USER/.ssh/id_rsa.pub >> /home/$HADOOP_USER/.ssh/authorized_keys"
sudo chown -R $HADOOP_USER:$HADOOP_GROUP /home/$HADOOP_USER/.ssh
sudo chmod 600 /home/$HADOOP_USER/.ssh/authorized_keys

echo "=== Step 5: Downloading and Installing Hadoop ==="
sudo -u $HADOOP_USER mkdir -p /home/$HADOOP_USER/mapreduce/software
cd /home/$HADOOP_USER/mapreduce/software
wget -q https://archive.apache.org/dist/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz
tar -xzf hadoop-${HADOOP_VERSION}.tar.gz
sudo mkdir -p $HADOOP_HOME
sudo rm -rf $HADOOP_HOME/*  # Clear if any old files exist
sudo mv hadoop-${HADOOP_VERSION}/* $HADOOP_HOME
sudo chown -R $HADOOP_USER:$HADOOP_GROUP $HADOOP_HOME

echo "=== Step 6: Configuring Hadoop Environment Variables ==="
# Avoid appending duplicates by removing old entries first:
sudo -u $HADOOP_USER sed -i '/# HADOOP VARIABLES START/,/# HADOOP VARIABLES END/d' /home/$HADOOP_USER/.bashrc

cat <<EOF | sudo tee -a /home/$HADOOP_USER/.bashrc
# HADOOP VARIABLES START
export JAVA_HOME=/usr/lib/jvm/java-8-openjdk-amd64
export HADOOP_HOME=$HADOOP_HOME
export PATH=\$PATH:\$HADOOP_HOME/bin:\$HADOOP_HOME/sbin
export HADOOP_MAPRED_HOME=\$HADOOP_HOME
export HADOOP_COMMON_HOME=\$HADOOP_HOME
export HADOOP_HDFS_HOME=\$HADOOP_HOME
export YARN_HOME=\$HADOOP_HOME
export HADOOP_COMMON_LIB_NATIVE_DIR=\$HADOOP_HOME/lib/native
export HADOOP_OPTS="-Djava.library.path=\$HADOOP_HOME/lib"
# HADOOP VARIABLES END
EOF

echo "=== Step 6.1: Source .bashrc for $HADOOP_USER ==="
# Source .bashrc for hduser to apply env vars for this session (must be done as hduser)
sudo -u $HADOOP_USER bash -c "source /home/$HADOOP_USER/.bashrc"

echo "=== Step 6.2: Updating hadoop-env.sh ==="
sudo sed -i '/^export JAVA_HOME/d' $HADOOP_HOME/etc/hadoop/hadoop-env.sh
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
   <name>fs.defaultFS</name>
   <value>hdfs://localhost:54310</value>
 </property>
</configuration>
EOF

echo "=== Step 6.5: Configuring mapred-site.xml ==="
sudo cp $HADOOP_HOME/etc/hadoop/mapred-site.xml.template $HADOOP_HOME/etc/hadoop/mapred-site.xml
cat <<EOF | sudo tee $HADOOP_HOME/etc/hadoop/mapred-site.xml
<configuration>
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
sudo -u $HADOOP_USER $HADOOP_HOME/bin/hdfs namenode -format -force

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
echo "To start Hadoop as $HADOOP_USER, run:"
echo " sudo -u $HADOOP_USER start-dfs.sh && sudo -u $HADOOP_USER start-yarn.sh "

echo "Alternatively, you can:"
echo " sudo -i -u $HADOOP_USER bash -c 'start-dfs.sh && start-yarn.sh' "
