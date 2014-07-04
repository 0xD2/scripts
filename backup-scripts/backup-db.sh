#!/bin/bash

############################################################################################
#Backup script via ftp (MySQL Databases)                                                   #
# usage:                                                                                   #
#       script.sh cleanold -- delete old backup, count of dumps specified in config file.  #
#       script.sh backup -- make backup.                                                   #
# Put script in cron w/ required option.                                                   #
# Example: every week, save backup for a 1 month.                                          #
# 1 0 * * 1 /bin/bash /opt/backup-db.sh backup                                             #
# 0 1 * * 1 /bin/bash /opt/backup-db.sh cleanold                                           #
# edit in 'backup_conf' option NUMBACKUPS_DB=4                                             #
#                                                                                          #
# OR                                                                                       #
# /bin/bash /opt/backup-db.sh backup -- for make backup immediatly.                        #
#                                                                                          #
############################################################################################


#config
. backup_conf

cd $WORK_DIR
mkdir -p $BACKUP_DIR/$MYSQL_DIR
touch $BACKLOG

arch_name="`date '+%Y-%m-%d--%H-%M'`"

echo2file() {
        message=$1
#        date_log="`date +%F--%H:%M:%S`"
        echo "[`date +%F--%H:%M:%S`] $message" >> $BACKLOG

}

echo2file "====START DATABASE BACKUP===="


#create new mysqldump bases from mysql_bd
mysql_archive()
{

		cd $BACKUP_DIR/$MYSQL_DIR
		echo2file "ARCHIVE: Im in `pwd`"
		rm -f ./*

		for i in $mysql_bd;
		do
        		/usr/bin/mysqldump --opt --add-drop-table --force --user=$mysqluser $i  > $i.sql
			if [[ $? -gt 0 ]]; then
				 echo2file "ARCHIVE: Dump db $i -- failed."
				 exit 1;
			else
				 echo2file "ARCHIVE: Dump db $i -- successfull."
			fi

			echo2file "ARCHIVE: Start archiving dump of $i"

			tar cfz ${i}_${arch_name}.dump.tar.gz $i.sql
			if [[ $? -gt 0 ]]; then
                                 echo2file "ARCHIVE: Cant create archives in dir `pwd`."
                                 exit 1;
                        else
                                 echo2file "ARCHIVE: Archive created successful."
                        fi
		done

        }

#delete old db backups from ftp
delete_old_db_ftp ()
{
	db=$1
	echo2file "DELETE: Deleting old db backups for $db."
        for i in `cat /tmp/list_bk | grep $db | head -n -$NUMBACKUPS_DB`;
        	do
        		echo2file "DELETE: Deleting dump $i."
			/usr/bin/ftp -v -n -i $HOST 1>>$BACKLOG <<EOF
        		user $USERNAME $PASS
        		cd $BACKUP_DIR/$MYSQL_DIR
			pwd
        		delete $i
        		bye
EOF
        done
}

rotate_db()
{

	echo2file "ROTATE: Im in `pwd`"

	/usr/bin/ftp -n -i $HOST 1>/tmp/ftp_list <<EOF
	user $USERNAME $PASS
	cd $BACKUP_DIR
	dir $MYSQL_DIR
	bye
EOF

	cat /tmp/ftp_list | awk '{print $9}' | grep 'tar.gz'  > /tmp/list_bk

        for i in $mysql_bd;
              do
		if (("`cat /tmp/list_bk | grep $i | wc -l`" < "$NUMBACKUPS_DB" ));  then
                	echo2file "ROTATE: Database $i has less then $NUMBACKUPS_DB dumps, nothing delete!"
        	else
			echo2file "ROTATE: Database $i has more then $NUMBACKUPS_DB, trying delete old dumps:"
                	delete_old_db_ftp "$i"
        	fi
	done
        rm -f /tmp/list_bk /tmp/ftp_list

}

put_backup()
{
 	echo2file "PUT_BACKUP: Putting dump backups to FTP server..."

	cd $WORK_DIR/$BACKUP_DIR/$MYSQL_DIR
	echo2file "PUT_BACKUP: Im in `pwd`"

	/usr/bin/ftp -v -n -i $HOST 1>>$BACKLOG <<EOF
        user $USERNAME $PASS
        cd $BACKUP_DIR/$MYSQL_DIR
        mput *.dump.tar.gz
        bye
EOF

	echo2file "PUT_BACKUP: End uploading backups..."

}


case "$1" in
        "cleanold") rotate_db  ;;
        "backup") mysql_archive; put_backup ;;
        *) echo "script without parameters" ; exit 1 ;;
esac


echo2file "====END DATABASE BACKUP===="
