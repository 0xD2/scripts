#!/bin/bash

############################################################################################
#Backup script via ftp (MySQL Databases)                                                                    #
# usage:                                                                                   #
#       script.sh cleanold -- delete old backup, count of dumps specified in config file.  #
#       script.sh backup -- make backup.                                                   #
# Put script in cron w/ required option.                                                   #
# Example: every week, save backup for a 1 month.                                          #
# 1 0 * * 1 /bin/bash /opt/backup-f.sh backup                                              #
# 0 1 * * 1 /bin/bash /opt/backup-f.sh cleanold                                            #
# OR                                                                                       #
# /bin/bash /opt/backup-f.sh backup -- for make backup immediatly.                         #
#                                                                                          #
############################################################################################


#config
. backup_conf

cd $WORK_DIR
mkdir -p $BACKUP_DIR/$MYSQL_DIR
touch $BACKLOG

arch_name="`date '+%Y-%m-%d--%H-%M'`"

echo "[`date +%F--%H-%M`] ====START DATABASE BACKUP====" >> $BACKLOG


#create new mysqldump bases from mysql_bd
mysql_archive()
{

		cd $BACKUP_DIR/$MYSQL_DIR
		echo "[`date +%F--%H-%M`] ARCHIVE: Im in `pwd`" >> $BACKLOG
		rm -f ./*

		for i in $mysql_bd;
		do
        		/usr/bin/mysqldump --opt --add-drop-table --force --user=$mysqluser $i  > $i.sql
			if [[ $? -gt 0 ]]; then
				 echo "[`date +%F--%H-%M`] ARCHIVE: Dump db $i -- failed." >> $BACKLOG
				 exit 1;
			else
				 echo "[`date +%F--%H-%M`] ARCHIVE: Dump db $i -- successfull." >> $BACKLOG
			fi

			echo "[`date +%F--%H-%M`] ARCHIVE: Start archiving dump of $i" >> $BACKLOG

			tar cfz ${i}_${arch_name}.dump.tar.gz $i.sql
			if [[ $? -gt 0 ]]; then
                                 echo "[`date +%F--%H-%M`] ARCHIVE: Cant create archives in dir `pwd`." >> $BACKLOG
                                 exit 1;
                        else
                                 echo "[`date +%F--%H-%M`] ARCHIVE: Archive created successful.  " >> $BACKLOG
                        fi
		done

        }

#delete old db backups from ftp
delete_old_db_ftp ()
{
	db=$1
	echo "[`date +%F--%H-%M`] DELETE: Deleting old db backups for $db." >> $BACKLOG
        for i in `cat /tmp/list_bk | grep $db | head -n -$NUMBACKUPS_DB`;
        	do
        		echo "[`date +%F--%H-%M`] DELETE: Deleting dump $i.">> $BACKLOG
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

	echo "[`date +%F--%H-%M`] ROTATE: Im in `pwd`" >> $BACKLOG

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
                	echo "[`date +%F--%H-%M`] ROTATE: Database $i has less then $NUMBACKUPS_DB dumps, nothing delete!" >> $BACKLOG
        	else
			echo "[`date +%F--%H-%M`] ROTATE: Database $i has more then $NUMBACKUPS_DB, trying delete old dumps:" >> $BACKLOG
                	delete_old_db_ftp "$i"
        	fi
	done
        rm -f /tmp/list_bk /tmp/ftp_list

}

put_backup()
{
 	echo "[`date +%F--%H-%M`] PUT_BACKUP: Putting dump backups to FTP server..." >> $BACKLOG

	cd $WORK_DIR/$BACKUP_DIR/$MYSQL_DIR
	echo "[`date +%F--%H-%M`] PUT_BACKUP: Im in `pwd`" >> $BACKLOG

	/usr/bin/ftp -v -n -i $HOST 1>>$BACKLOG <<EOF
        user $USERNAME $PASS
        cd $BACKUP_DIR/$MYSQL_DIR
        mput *.dump.tar.gz
        bye
EOF

	echo "[`date +%F--%H-%M`] PUT_BACKUP: End uploading backups..." >> $BACKLOG

}


case "$1" in
        "cleanold") rotate_db  ;;
        "backup") mysql_archive; put_backup ;;
        *) echo "script without parameters" ; exit 1 ;;
esac


echo "[`date +%F--%H-%M`] ====END DATABASE BACKUP====" >> $BACKLOG
