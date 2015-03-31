#!/bin/bash

# inspired by init scripts of CDH4

# Starts a Zookeeper server
#
# chkconfig: 345 85 15
# description: Zookeeper server
#
### BEGIN INIT INFO
# Provides:          hdp-zookeeper
# Short-Description: Zookeeper server
# Default-Start:     3 4 5
# Default-Stop:      0 1 2 6
# Required-Start:    $syslog $remote_fs
# Required-Stop:     $syslog $remote_fs
# Should-Start:
# Should-Stop:
### END INIT INFO

. /lib/lsb/init-functions
. /etc/default/hadoop

if [ -f /etc/default/hadoop-custom ] ; then
  . /etc/default/hadoop-custom
fi

export ZOOCFGDIR=$ZOOKEEPER_CONF_DIR
export ZOOPIDFILE=$ZOOKEEPER_PID_DIR"/zookeeper_server.pid"
export ZOOLOGFILE=$ZOOKEEPER_LOG_DIR"/zoo.out"

##

RETVAL_SUCCESS=0

STATUS_RUNNING=0
STATUS_DEAD=1
STATUS_DEAD_AND_LOCK=2
STATUS_NOT_RUNNING=3
STATUS_OTHER_ERROR=102

ERROR_PROGRAM_NOT_INSTALLED=5
ERROR_PROGRAM_NOT_CONFIGURED=6

RETVAL=0
SLEEP_TIME=5
PROC_NAME="java"

DAEMON="hdp-zookeeper"
DESC="Zookeeper server"
EXEC_PATH="/usr/lib/zookeeper/bin/zkServer.sh"
SVC_USER=$ZOOKEEPER_USER
CONF_DIR=$ZOOKEEPER_CONF_DIR
PIDFILE=$ZOOPIDFILE
LOCKDIR="/var/lock/subsys"
LOCKFILE="$LOCKDIR/zookeeper_server"
WORKING_DIR="/var/lib/zookeeper"

install -d -m 0755 -o $ZOOKEEPER_USER -g $HADOOP_GROUP "$ZOOKEEPER_PID_DIR" 1>/dev/null 2>&1 || :
[ -d "$LOCKDIR" ] || install -d -m 0755 $LOCKDIR 1>/dev/null 2>&1 || :

start() {
  [ -x $EXEC_PATH ] || exit $ERROR_PROGRAM_NOT_INSTALLED
  [ -d $CONF_DIR ] || exit $ERROR_PROGRAM_NOT_CONFIGURED
  log_success_msg "Starting ${DESC}: "

  su -s /bin/bash $SVC_USER -c "source $ZOOKEEPER_CONF_DIR/zookeeper-env.sh ; cd $WORKING_DIR && $EXEC_PATH start >> $ZOOLOGFILE 2>&1"
  # PIDFILE will be generated by zkServer

  # Some processes are slow to start
  sleep $SLEEP_TIME
  checkstatusofproc
  RETVAL=$?

  [ $RETVAL -eq $RETVAL_SUCCESS ] && touch $LOCKFILE
  return $RETVAL
}

stop() {
  log_success_msg "Stopping ${DESC}: "
  su -s /bin/bash $SVC_USER -c "$EXEC_PATH stop"
  RETVAL=$?

  [ $RETVAL -eq $RETVAL_SUCCESS ] && rm -f $LOCKFILE $PIDFILE
}

restart() {
  stop
  start
}

checkstatusofproc(){
  pidofproc -p $PIDFILE $PROC_NAME > /dev/null
}

checkstatus(){
  checkstatusofproc
  status=$?

  case "$status" in
    $STATUS_RUNNING)
      log_success_msg "${DESC} is running"
      ;;
    $STATUS_DEAD)
      log_failure_msg "${DESC} is dead and pid file exists"
      ;;
    $STATUS_DEAD_AND_LOCK)
      log_failure_msg "${DESC} is dead and lock file exists"
      ;;
    $STATUS_NOT_RUNNING)
      log_failure_msg "${DESC} is not running"
      ;;
    *)
      log_failure_msg "${DESC} status is unknown"
      ;;
  esac
  return $status
}

check_for_root() {
  if [ $(id -ur) -ne 0 ]; then
    echo 'Error: root user required'
    echo
    exit 1
  fi
}

service() {
  case "$1" in
    start)
      check_for_root
      start
      ;;
    stop)
      check_for_root
      stop
      ;;
    status)
      checkstatus
      RETVAL=$?
      ;;
    restart)
      check_for_root
      restart
      ;;
    *)
      echo $"Usage: $0 {start|stop|status|restart}"
      exit 1
  esac
}

service "$1"

exit $RETVAL
