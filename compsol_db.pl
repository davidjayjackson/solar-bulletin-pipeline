#!/usr/bin/perl -w

# This is COMPSOL_DB.PL -- Version 1.0.1
# Author: Matthew Templeton, AAVSO HQ
# Date: 2012 June 15
# CHANGES:
# Version 1.0.2 -- added clause to exclude older verions of an observers sun_obsconst record
# Version 1.0.1 -- changing solar data table output and 
#                  adding observer name to tally table

# PLEASE DO NOT MODIFY THIS CODE -- AAVSO HEADQUARTERS CANNOT SUPPORT CODE 
# ONCE IT HAS BEEN MODIFIED


use DBI;

# Predefined values
# If an observer does not have a k or Weight, they must be assigned.  What
# should they be?  NOTE: These should be consistent with past values or
# else changes to long-term statistics may occur.

$kval=1.0;
$wval=0.05;

$nmoday=-1;

open(A,"<aavso.srt");
open(B,">soldata.txt");
chomp($header=<A>);
$header=undef;
while(<A>){
  $x={
    JD=>substr($_,0,10),
    G=>substr($_,11,4),
    S=>substr($_,16,4),
    C=>substr($_,21,4),
    KC=>substr($_,26,7),
    LC=>substr($_,34,6),
    LK=>substr($_,41,6),
    XW=>substr($_,48,6),
    OB=>substr($_,54,4),
    NM=>substr($_,59,20),
    SEE=>substr($_,84,1)
  };
  push(@inlines,$x);
}
close(A);

$lastday=-99999.9999;
$numdat=0;
$nobsave=0;
$nobsdays=0;

%obsconst=&obsconst;

$dave[1]=0;
$dsig[1]=0;
$dave[2]=0;
$dsig[2]=0;
$dave[3]=0;
$dsig[3]=0;
$dcount=0;
$dkount=0;
$nolog=0;

#print B "day   ave    stdev   k-ave   stdev\n";
print B "DAY    NumObs    RAW     Ra\n";
foreach $y (@inlines) {
# $see=$y->{SEE};
# if($see eq 'F' || $see eq 'P') {
# } else {
  $jd=$y->{JD};
  $dcount=$y->{C};
  $ob=$y->{OB};
  $ob=~s/\s+//g;
  $dconst=$obsconst{$ob}->{XC};
  $dweight=$obsconst{$ob}->{XW};
  if(defined($dconst)){
  } else {
    print "For observer $ob k and Weight are NOT DEFINED!\n";
    $dconst=$kval;
    $dweight=$wval;
  }

  $lday=int($jd + 0.50001);
  if($lday != $lastday) {
    &compdaily;
    $lastday=$lday;
  }
  $dkount=$dcount*$dconst;
  $numdat++;
  $dave[1]=$dave[1] + $dcount;
  $dsig[1]=$dsig[1] + ($dcount*$dcount);
  $dave[2]=$dave[2] + ($dweight*$dkount);
  $dsig[2]=$dsig[2] + ($dweight*$dkount**2);
  if ($dkount > 0) {
    $dklog=log($dkount);
    $dave[3]=$dave[3] + ($dweight*$dklog);
    $dsig[3]=$dsig[3] + ($dweight*$dklog**2);
  } else {
    $nolog=-1;
  }
  $dwsum+=$dweight;
  $dwsum2+=$dweight**2;
# }
}
&compdaily;

$avenumobs=($nobsave*1.0)/($nobsdays*1.0);
printf B "Average  %6.1f   %6.1f   %6.1f\n",$avenumobs,$dmave[1]/$nmoday,$dmave[2]/$nmoday;


#Now prep and print the footer summaries....
foreach $l (@inlines) {
  $o=$l->{OB};
  if(defined($count{$o})){
    $count{$o}++;
  } else {
    $count{$o}=1;
  }
}

@obswdat=keys(%count);
@obswsort=sort(@obswdat);
print B "Number of observations by observer:\n";
print B "===================================\n";
foreach $o (@obswsort) {
  $o2=$o;
  $o2=~s/\s+//;
  printf B "%-4s  %4i   %s\n",$o,$count{$o},$obsconst{$o2}->{NM};
}
print B "===================================\n";
$nobsvr=@obswdat;
printf B "No. of Observers: %3i\n",$nobsvr;
print B "===================================\n";
$nlines=@inlines;
printf B "Total No. of Observations: %4i\n",$nlines;

close(B);
 

sub compdaily {
  $nmoday++;
  if($numdat < 1) {
    return;
  } else {
#   $dsqnum=1./sqrt($numdat*1.0);
    $dave[1]/=$numdat;
    $dave[2]/=$dwsum;
    if($nolog == 0) {
      $dave[3]/=$dwsum;
    } else {
      $dave[3]=-1;
    }
    if($numdat > 1) {
      $dsig[1]=($dsig[1]/$numdat) - ($dave[1]**2);
      $dsig[1]=sqrt(($dsig[1]*$numdat)/($numdat -1));
      $dsig[2]=($dsig[2]/$dwsum) - ($dave[2]**2);
      $dfact=1.-($dwsum2/$dwsum**2);
      $dsig[2]=sqrt($dsig[2]/$dfact);
      if($nolog==0) {
        $dsig[3]=($dsig[3]/$dwsum) - $dave[3]**2;
        $dsig[3]=sqrt($dsig[3]*$numdat/($numdat-1));
      } else {
        $dsig[3]=-1.;
      }
    } else {
      $dsig[1]=0.;
      $dsig[2]=0.;
      $dsig[3]=0.;
    }
    if($nolog == 0) {
      $dave[3]=exp($dave[3]);
      $dsig[3]=exp($dsig[3]);
      $dsig[3]=($dsig[3]-1)*$dave[3];
    }
# now start printing the daily summary...
    $davep[1]=int($dave[1]+0.5);
    $davep[2]=int($dave[2]+0.5);
    $davep[3]=int($dave[3]+0.5);

#   printf B "%2i   %4i   %6.1f   %4i   %6.1f\n",$nmoday,$davep[1],$dsqnum*$dsig[1],$davep[2],$dsqnum*$dsig[2];
    printf B "%2i   %4i   %4i   %4i\n",$nmoday,$numdat,$davep[1],$davep[2];

  }
  $dmave[1]+=$dave[1];
  $dmave[2]+=$dave[2];
  $dmave[3]+=$dave[3];
  $nobsave+=$numdat;
  $nobsdays++;
  $numdat=0;
  $dwsum=0;
  $dwsum2=0;
  $nolog=0;
  $dave[1]=0.;
  $dsig[1]=0.;
  $dave[2]=0.;
  $dsig[2]=0.;
  $dave[3]=0.;
  $dsig[3]=0.;
  return;
}


sub obsconst {
  $dbh=getdbh("solar","db.aavso.org","solarobs","blab_blab!");
  $q_o="select k,Scale,name,Obs,AAVSO_obscode,SIDC_submitter,updated from sun_obsconst where revised = 0 order by Obs";
  $sth=$dbh->prepare($q_o);
  $sth->execute();
  $ref=$sth->fetchall_arrayref();
  foreach $r (@{$ref}){
    @row=@{$r};
    if($row[0] == 0) {
      $row[0] = $kval;
    }
    if($row[1] == 0) {
      $row[1] = $wval;
    }
    $x={
      OC=>$row[3],
      XC=>$row[0],
      XW=>$row[1],
      NM=>$row[2]
    };
    $obsdat{$row[3]}=$x;
  }
  $sth->finish();
  $dbh->disconnect();
  return %obsdat;
}



sub getdbh {

  #
  # getdbh -- a subroutine that returns a MySQL database handle for a
  # user-supplied database name.
  #
  # calling syntax:  $dbh=getdbh($database_name);
  #
  #     $dbh == database handle
  #     $database_name == name of MySQL db you wish to connect to.
  #
  # Author: M. Templeton, AAVSO, 2009 December 10
  #

  $dbname=$_[0];
  $host=$_[1];
  $user=$_[2];
  $pass=$_[3];
  $dbh=DBI->connect("DBI:mysql:$dbname;host=$host;user=$user;password=$pass");
  return $dbh;

}
