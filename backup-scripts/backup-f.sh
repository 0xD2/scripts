#!/bin/bash

############################################################################################
#Backup script via ftp (content)							   #
# usage:										   #
#	script.sh cleanold -- delete old backup, count of dumps specified in config file.  #
#	script.sh backup -- make backup.						   #
# Put script in cron w/ required option. 						   #
# Example: every week, save backup for a 1 month.					   #
# 1 0 * * 1 /bin/bash /opt/backup-f.sh backup						   #
# 0 1 * * 1 /bin/bash /opt/backup-f.sh cleanold						   #
# edit in 'backup_conf' option NUMBACKUPS=4			    	   		   #
#		   									   #
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


echo2file() {
	message=$1
	date_log="`date +%F--%H-%M`"
	echo "[$date_log] $message" >> $BACKLOG

}

echo2file("====START CONTENT BACKUP====")

#create new content archive from BACKUP_FILES
content_archive()
{

		cd $BACKUP_DIR/$CONTENT_DIR
		echo2file("ARCHIVE: Im in `pwd`")
		rm -f ./*

		for DIR in ${BACKUP_FILES[@]};
		do
			echo2file("ARCHIVE: Trying create archive for $DIR.")

			tar rf $arch_name.tar $DIR &>> $BACKLOG
			if [[ $? -gt 0 ]]; then
                                 echo2file("ARCHIVE: Archive content $DIR -- failed.")
                                 exit 1;
                        else
                                 echo2file("ARCHIVE: Archive content $DIR -- successfull.")
                        fi

        	done;

		gzip -7 $arch_name.tar
		if [[ $? -gt 0 ]]; then
                	echo2file("ARCHIVE: Cant gzip tar-files failed.")
                        exit 1;
                else
                        echo2file("ARCHIVE: Gzip tar-files successfull.")
                fi
        }

#delete old content backups from ftp
delete_old_content_ftp ()
{
	file=$1
	echo2file("DELETE: Deleting old content backups: $file.")
        for i in `cat /tmp/list_bk | head -n -$NUMBACKUPS`;
        	do
        		echo2file("DELETE: Deleting $i.")
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

	echo2file("ROTATE: Im in `pwd`")

	ftp -n -i $HOST 1>/tmp/ftp_list <<EOF
	user $USERNAME $PASS
	cd $BACKUP_DIR
	dir $CONTENT_DIR
	bye
EOF

	cat /tmp/ftp_list | awk '{print $9}' | grep 'tar.gz'  > /tmp/list_bk

	if (("`cat /tmp/list_bk | wc -l`" < "$NUMBACKUPS" ));  then
               	echo2file("ROTATE: Content $i has less then $NUMBACKUPS dumps, nothing delete!")
       	else
		echo2file("ROTATE: Content $i has more then $NUMBACKUPS, trying delete old archives:")
               	delete_old_content_ftp
       	fi
        rm -f /tmp/list_bk /tmp/ftp_list

}

put_backup()
{
 	echo2file("PUT_BACKUP: Putting backups to FTP server...")

	cd $WORK_DIR/$BACKUP_DIR/$CONTENT_DIR
	echo2file("PUT_BACKUP: Im in `pwd`")

	ftp -v -n -i $HOST 1>>$BACKLOG <<EOF
        user $USERNAME $PASS
        cd $BACKUP_DIR/$CONTENT_DIR
        mput *.tar.gz
        bye
EOF

	echo2file("PUT_BACKUP: End uploading backups...")

}


case "$1" in
        "cleanold") rotate_content  ;;
        "backup") content_archive; put_backup ;;
        *) echo "script without parameters" ; exit 1 ;;
esac

echo2file("====END CONTENT BACKUP====")
