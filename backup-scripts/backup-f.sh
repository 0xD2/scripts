#!/bin/bash

############################################################################################
#Backup script via ftp (content)							   #
# usage:										   #
#	script.sh cleanold -- delete old backup, count of dumps specified in config file.  #
#	script.sh backup -- make backup.						   #
# Put script in cron w/ required option. 						   #
# Example: every week, save backup for a 1 month.					   #
# 1 0 * * 1 /bin/bash /opt/backup-f.sh backup						   #
# 0 1 * * 1 /bin/bash /opt/backup-f.sh cleanold 					   #
# OR 											   #
# /bin/bash /opt/backup-f.sh backup -- for make backup immediatly.			   #
#										 	   #
############################################################################################


#config
. backup_conf

cd $WORK_DIR
mkdir -p $BACKUP_DIR/$CONTENT_DIR
touch $BACKLOG

arch_name="`date '+%Y-%m-%d--%H-%M'`"

echo "[`date +%F--%H-%M`] ====START CONTENT BACKUP====" >> $BACKLOG


#create new content archive from BACKUP_FILES
content_archive()
{

		cd $BACKUP_DIR/$CONTENT_DIR
		echo "[`date +%F--%H-%M`] ARCHIVE: Im in `pwd`" >> $BACKLOG
		rm -f ./*

		for DIR in ${BACKUP_FILES[@]};
		do
			echo "[`date +%F--%H-%M`] ARCHIVE: Trying create archive for $DIR." >> $BACKLOG

			tar rf $arch_name.tar $DIR &>> $BACKLOG
			if [[ $? -gt 0 ]]; then
                                 echo "[`date +%F--%H-%M`] ARCHIVE: Archive content $DIR -- failed." >> $BACKLOG
                                 exit 1;
                        else
                                 echo "[`date +%F--%H-%M`] ARCHIVE: Archive content $DIR -- successfull." >> $BACKLOG
                        fi

        	done;

		gzip -7 $arch_name.tar
		if [[ $? -gt 0 ]]; then
                	echo "[`date +%F--%H-%M`] ARCHIVE: Cant gzip tar-files failed." >> $BACKLOG
                        exit 1;
                else
                        echo "[`date +%F--%H-%M`] ARCHIVE: Gzip tar-files successfull." >> $BACKLOG
                fi
        }

#delete old content backups from ftp
delete_old_content_ftp ()
{
	file=$1
	echo "[`date +%F--%H-%M`] DELETE: Deleting old content backups: $file." >> $BACKLOG
        for i in `cat /tmp/list_bk | head -n -$NUMBACKUPS`;
        	do
        		echo "[`date +%F--%H-%M`] DELETE: Deleting $i.">> $BACKLOG
			ftp -v -n -i $HOST 1>>$BACKLOG <<EOF
        		user $USERNAME $PASS
        		cd $BACKUP_DIR/$CONTENT_DIR
			pwd
        		delete $i
        		bye
EOF
        done
}

rotate_content()
{

	echo "[`date +%F--%H-%M`] ROTATE: Im in `pwd`" >> $BACKLOG

	ftp -n -i $HOST 1>/tmp/ftp_list <<EOF
	user $USERNAME $PASS
	cd $BACKUP_DIR
	dir $CONTENT_DIR
	bye
EOF

	cat /tmp/ftp_list | awk '{print $9}' | grep 'tar.gz'  > /tmp/list_bk

	if (("`cat /tmp/list_bk | wc -l`" < "$NUMBACKUPS" ));  then
               	echo "[`date +%F--%H-%M`] ROTATE: Content $i has less then $NUMBACKUPS dumps, nothing delete!" >> $BACKLOG
       	else
		echo "[`date +%F--%H-%M`] ROTATE: Content $i has more then $NUMBACKUPS, trying delete old archives:" >> $BACKLOG
               	delete_old_content_ftp
       	fi
        rm -f /tmp/list_bk /tmp/ftp_list

}

put_backup()
{
 	echo "[`date +%F--%H-%M`] PUT_BACKUP: Putting backups to FTP server..." >> $BACKLOG

	cd $WORK_DIR/$BACKUP_DIR/$CONTENT_DIR
	echo "[`date +%F--%H-%M`] PUT_BACKUP: Im in `pwd`" >> $BACKLOG

	ftp -v -n -i $HOST 1>>$BACKLOG <<EOF
        user $USERNAME $PASS
        cd $BACKUP_DIR/$CONTENT_DIR
        mput *.tar.gz
        bye
EOF

	echo "[`date +%F--%H-%M`] PUT_BACKUP: End uploading backups..." >> $BACKLOG

}


case "$1" in
        "cleanold") rotate_content  ;;
        "backup") content_archive; put_backup ;;
        *) echo "script without parameters" ; exit 1 ;;
esac

echo "[`date +%F--%H-%M`] ====END CONTENT BACKUP====" >> $BACKLOG
