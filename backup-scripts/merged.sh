#!/bin/bash

#################################################################################################
# Merged backup script via ftp (content & databases)					   	#
# usage:										   	#
#	script.sh cleanold -- delete old backup, count of dumps specified in config file.  	#
#	script.sh backup -- make backup.						   	#
# Put script in cron w/ required option. 						   	#
# Example: every week, save backup for a 1 month.					   	#
# 1 0 * * 1 /bin/bash /opt/backup.sh <db/content> backup					#
# 0 1 * * 1 /bin/bash /opt/backup.sh <db/content> cleanold				   	#
# edit in 'backup_conf' option NUMBACKUPS=4			    	   		   	#
#		   									   	#
# OR 											   	#
# /bin/bash /opt/backup.sh <db/content> backup -- for make "db" or "content" backup immediatly. #
#										 	   	#
#################################################################################################


#config
. backup_conf

cd $WORK_DIR
touch $BACKLOG

arch_name="`date '+%Y-%m-%d--%H-%M'`"

echo2file() {
	message="$1"
#	date_log=`date +%F--%H:%M:%S`
	echo "[`date +%F--%H:%M:%S`] $message" >> $BACKLOG

}

echo2file "=====START BACKUP====="

#create new content archive from BACKUP_FILES
content_archive()
{
		mkdir -p $BACKUP_DIR/$CONTENT_DIR
		cd $BACKUP_DIR/$CONTENT_DIR
		echo2file "ARCHIVE: Im in `pwd`"
		rm -f ./*

		for DIR in ${BACKUP_FILES[@]};
		do
			echo2file "ARCHIVE: Trying create archive for $DIR."

			tar rf $arch_name.tar $DIR &>> $BACKLOG
			if [[ $? -gt 0 ]]; then
                                 echo2file "ARCHIVE: Archive content $DIR -- failed."
                                 exit 1;
                        else
                                 echo2file "ARCHIVE: Archive content $DIR -- successfull."
                        fi
        	done;

		gzip -7 $arch_name.tar
		if [[ $? -gt 0 ]]; then
                	echo2file "ARCHIVE: Cant gzip tar-files failed."
                        exit 1;
                else
                        echo2file "ARCHIVE: Gzip tar-files successfull."
                fi
        }

#create new mysqldump bases from mysql_bd
mysql_archive()
{
		mkdir -p $BACKUP_DIR/$MYSQL_DIR
                cd $BACKUP_DIR/$MYSQL_DIR
                echo2file "ARCHIVE_DB: Im in `pwd`"
                rm -f ./*

                for i in $mysql_bd;
                do
                        /usr/bin/mysqldump --opt --add-drop-table --force --user=$mysqluser $i  > $i.sql
                        if [[ $? -gt 0 ]]; then
                                 echo2file "ARCHIVE_DB: Dump db $i -- failed."
                                 exit 1;
                        else
                                 echo2file "ARCHIVE_DB: Dump db $i -- successfull."
                        fi
                        echo2file "ARCHIVE_DB: Start archiving dump of $i"

                        tar cfz ${i}_${arch_name}.dump.tar.gz $i.sql
                        if [[ $? -gt 0 ]]; then
                                 echo2file "ARCHIVE_DB: Cant create archives in dir `pwd`."
                                 exit 1;
                        else
                                 echo2file "ARCHIVE_DB: Archive created successful."
                        fi
                done

}



#delete old content backups from ftp
delete_old_ftp_content ()
{
	file=$1
	echo2file "DELETE: Deleting old content backups: $file."
        for i in `cat /tmp/list_bk | head -n -$NUMBACKUPS`;
        	do
        		echo2file "DELETE: Deleting $i."
			ftp -v -n -i $HOST 1>>$BACKLOG <<EOF
        		user $USERNAME $PASS
        		cd $BACKUP_DIR/$CONTENT_DIR
			pwd
        		delete $i
        		bye
EOF
        done
}

#delete old db backups from ftp
delete_old_ftp_db ()
{
        db=$1
        echo2file "DELETE_DB: Deleting old db backups for $db."
        for i in `cat /tmp/list_bk | grep $db | head -n -$NUMBACKUPS_DB`;
                do
                        echo2file "DELETE_DB: Deleting dump $i."
                        /usr/bin/ftp -v -n -i $HOST 1>>$BACKLOG <<EOF
                        user $USERNAME $PASS
                        cd $BACKUP_DIR/$MYSQL_DIR
                        pwd
                        delete $i
                        bye
EOF
        done
}

rotate_content()
{

	echo2file "ROTATE: Im in `pwd`"

	ftp -n -i $HOST 1>/tmp/ftp_list <<EOF
	user $USERNAME $PASS
	cd $BACKUP_DIR
	dir $CONTENT_DIR
	bye
EOF

	cat /tmp/ftp_list | awk '{print $9}' | grep 'tar.gz'  > /tmp/list_bk

	if (("`cat /tmp/list_bk | wc -l`" < "$NUMBACKUPS" ));  then
               	echo2file "ROTATE: Content $i has less then $NUMBACKUPS dumps, nothing delete!"
       	else
		echo2file "ROTATE: Content $i has more then $NUMBACKUPS, trying delete old archives:"
		delete_old_ftp_content
       	fi
        rm -f /tmp/list_bk /tmp/ftp_list
}

rotate_db()
{

        echo2file "ROTATE_DB: Im in `pwd`"

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
                        echo2file "ROTATE_DB: Database $i has less then $NUMBACKUPS_DB dumps, nothing delete!"
                else
                        echo2file "ROTATE_DB: Database $i has more then $NUMBACKUPS_DB, trying delete old dumps:"
                        delete_old_ftp_db "$i"
                fi
        done
        rm -f /tmp/list_bk /tmp/ftp_list
}

put_backup_content()
{
 	echo2file "PUT_BACKUP: Putting backups to FTP server..."

	cd $WORK_DIR/$BACKUP_DIR/$CONTENT_DIR
	echo2file "PUT_BACKUP: Im in `pwd`"

	ftp -v -n -i $HOST 1>>$BACKLOG <<EOF
        user $USERNAME $PASS
        cd $BACKUP_DIR/$CONTENT_DIR
        mput *.tar.gz
        bye
EOF
	echo2file "PUT_BACKUP: End uploading backups..."

}

put_backup_db()
{
        echo2file "PUT_BACKUP_DB: Putting dump backups to FTP server..."

        cd $WORK_DIR/$BACKUP_DIR/$MYSQL_DIR
        echo2file "PUT_BACKUP_DB: Im in `pwd`"

        /usr/bin/ftp -v -n -i $HOST 1>>$BACKLOG <<EOF
        user $USERNAME $PASS
        cd $BACKUP_DIR/$MYSQL_DIR
        mput *.dump.tar.gz
        bye
EOF

        echo2file "PUT_BACKUP_DB: End uploading backups..."
}


if [ "$1" = "content" ]; then

	case "$2" in
        	"cleanold") rotate_content  ;;
        	"backup") content_archive; put_backup_content ;;
        	*) echo "script without parameters" ; exit 1 ;;
	esac
elif [ "$1" = "db" ]; then

	case "$2" in
        	"cleanold") rotate_db  ;;
        	"backup") mysql_archive; put_backup_db ;;
        	*) echo "script without parameters" ; exit 1 ;;
	esac
else
	echo "Object not specified! Please, use \"db\" or \"conent\""

fi

echo2file "=====END BACKUP====="

