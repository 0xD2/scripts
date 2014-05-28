#!/usr/bin/perl

use Getopt::Long;

#help() if $#ARGV<0;
GetOptions(
        "backup=s" =>\$backup_node,
        "fe=s"        =>\$fe_node,
        "pool=s"          =>\$pool,
        "date=s"       =>\$date,
        "db"      =>\$db,
        "client=s"        =>\$client
        );
sub help()
{
                print STDERR <<EOF;
Usage:
        --backup [backupX]      : Specify hostname of BACKUP server
        --fe [feX]              : Specify fe server
        --pool                  : Specify pool on Backup server
        --date                  : Date of build creating, format DDMMYYYY
        --db                    : Add option for databases restore
        --client                : Specify client login
        without options         : Print this message
EOF
        exit;
}

sub checkSyntax
{
        if (!$backup_node or !$fe_node)
        {
                print "Check backup and fe parameters, see help:\n\n";
                help();
        }
        if (!$pool or !$date or !$client)
        {
                print "Check pool, date or client parameters, see help:\n\n";
                help();
        }

}

# command: rsync -avW --progress /backup1/fe/bk_fe73/.zfs/snapshot/11052014/content/artpilot/* fe73:/www/artpilot/backup/11052014

sub formIn
{
        $in = "/backup$pool/fe/bk_$fe_node/.zfs/snapshot/$date/content/$client";
        $inDB = "/backup$pool/fe/bk_$fe_node/.zfs/snapshot/$date/content/db/db_backup/$client";
}

sub formOut
{
        $out = "$fe_node:/www/$client/backup/files-$date";      # local path on fe-server for files
        $outDB = "$fe_node:/www/$client/backup/db-$date";      # local path on fe-server for dbs


}

checkSyntax();
formIn();
formOut();
#TODO: mkdir backup dir if not exist. 
#$dirDB = "ssh $fe_node \"mkdir -p /www/$client/backup/db-$date\"";
$command = "ssh $backup_node 'sudo rsync -avW --progress $in $out'";
$commandDB = "ssh $backup_node 'sudo rsync -avW --progress $inDB $outDB'";

$fixown = "ssh $fe_node 'sudo fixown $client'";

#$command = $command."\n";

print "Command: $command \n";           # Do backup
#system("$command");
system("$command") == 0 or die "Error: $@";
if ($db)
{
        print "\nCommand: ",$commandDB, "\n","\n"; # Im verbose! 
        system ($commandDB) == 0 or die "Error: $@";

}

system($fixown);

#for copy-paste
print "\nFiles:",$out;
print "\nDB: ",$outDB,"\n";

