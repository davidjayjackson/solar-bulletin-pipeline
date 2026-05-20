#!/usr/bin/perl -w

# This is RAWPROC_DB.PL -- Version 1.0
# Author: Matthew Templeton, AAVSO HQ
# Date: 2012 June 13

# PLEASE DO NOT MODIFY THIS CODE -- AAVSO HEADQUARTERS CANNOT SUPPORT CODE 
# ONCE IT HAS BEEN MODIFIED

use DBI;

# Predefined values
# If an observer does not have a k or Weight, they must be assigned.  What
# should they be?  NOTE: These should be consistent with past values or
# else changes to long-term statistics may occur.

$kval=1.0;
$wval=0.1;

@publish_uids=();


#Open database



# Perl arrays start with index=0, so padding the array with $months[0]="XXX"
# allows you to directly match Jan=1, Feb=2, etc...

@months=qw(XXX Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec);


$month=0;
while($month < 1 || $month > 12) {
  print "Enter the number of the month you want to process: ";
  chomp($month=<stdin>);
}

$year=0;
while($year < 1940) {
  print "Enter the year (4-digit): ";
  chomp($year=<stdin>);
}
$monthyr=$months[$month]." ".$year;

#Query database...
$q_get_observations="select * from sun_data where monthyr=? and revised=0 and (Obs != \"BSJ1\" and Obs != \"TMT\" and Obs != \"WEO\") order by Obs,day,ut";

$sth=$dbh->prepare($q_get_observations);

$sth->execute($monthyr);

$ref=$sth->fetchall_arrayref();
foreach $r (@{$ref}){
  @row=@{$r};
  if(defined($ohash{$row[15]})){
    $ohash{$row[15]}++;
  } else {
    $ohash{$row[15]}=1;
  }
  $datum={
    uid=>$row[0],
    date=>$row[1],
    monthyr=>$row[2],
    day=>$row[3],
    see=>$row[4],
    UT=>$row[5],
    g=>$row[6],
    s=>$row[7],
    W=>$row[8],
    ng=>$row[9],
    sg=>$row[10],
    ns=>$row[11],
    ss=>$row[12],
    cg=>$row[13],
    cs=>$row[14],
    Obs=>$row[15],
    Remarks=>$row[16],
    header_id=>$row[17],
    submitted=>$row[18],
    revised=>$row[19]
  };
  push(@observations,$datum);
  push(@publish_uids,$row[0]);
}
$sth->finish();

@olist=keys(%ohash);

$nobservers=@olist;
$ndata=@observations;

print "There were $ndata observations by $nobservers observers.\n";

&get_obsconst;

&make_soldata_srt;


# SHORT BLOCK TO MARK DATA POINTS AS PUBLISHED (AND THEREFORE NON-EDITABLE)

print "Updating sun_data to mark observations as published.... please wait.\n";
$q="update sun_data set published=1 where uid=?";
$sth=$dbh->prepare($q);
foreach $uid (@publish_uids) {
  $sth->execute($uid);
}
$sth->finish();

# ALL DONE WITH DATABASES, SO...

$dbh->disconnect();

# END OF MAIN PROGRAM....



# SUBROUTINES....


sub get_obsconst {
  $q_get_obsconst="select k,Scale,name,Obs,AAVSO_obscode,SIDC_submitter,updated from sun_obsconst where Obs=?";
  $sth=$dbh->prepare($q_get_obsconst);
  foreach $o (@olist) {
    $sth->execute($o);
    @row=$sth->fetchrow_array();
    $x={
      k=>$row[0],
      Scale=>$row[1],
      name=>$row[2],
      Obs=>$row[3],
      AAVSO=>$row[4],
      SIDC=>$row[5],
      updated=>$row[6]
    };
    $obsconst{$o}=$x;
  }
  $sth->finish();
}


sub make_soldata_srt {

  open(X,">soldata.srt");
  print X "   JD         g    s   c     kc   log(c) log(kc)  w   Obs.      Obs. Name\n";
  foreach $x (@observations) {
    $obs=$x->{Obs};
    $ut=$x->{UT};
#   $uth=substr($ut,0,2);
#   $utm=substr($ut,2,2);
#   $utf=($uth+($utm/60.))/24.;
    $day=$x->{day};
    $jd=old_solarjd($day,$month,$year,$ut);

    $s=$x->{s};
    $g=$x->{g};
    $W=$x->{W};
    $see=$x->{see};

    $xc=$obsconst{$obs}->{k};
    $xw=$obsconst{$obs}->{Scale};
    $name=$obsconst{$obs}->{name};
    $name="OBS NOT IN OBSCONST!" unless (defined($name));
    $name=substr($name,0,20);
    if(defined($xc)){
      if($xc eq "" || $xc == 0) {$xc=$kval;}
    } else {
      $xc=$kval;
    }
    if(defined($xw)){
      if($xw eq "" || $xw == 0) {$xw=$wval;}
    } else {
      $xw=$wval;
    }

# *Now* we start calculating things...
    $count=$s+(10*$g);
    if($count != $W){
      print "oops, W is not the same as count...\n";
#     $W=$count;
    }
    $kcount=int(10000.*($count*$xc)+0.5)/10000.;
    if($count > 0) {
      $logcount=log($count)/log(10.);
      $logkcount=log($kcount)/log(10.);
      $logcount=int(10000.*($logcount)+0.5)/10000.;
      $logkcount=int(10000.*($logkcount)+0.5)/10000.;
      $logcount=substr($logcount."0000",0,6);
      $logkcount=substr($logkcount."0000",0,6);
      if($logcount !~ /\./){$logcount="1.0000";}
      if($logkcount !~ /\./){$logkcount="1.0000";}
    } else {
      $logcount="-.----";
      $logkcount="-.----";
    }
    $x={
      JD=>$jd,
      G=>$g,
      S=>$s,
      W=>$W,
      KC=>$kcount,
      LC=>$logcount,
      LK=>$logkcount,
      XW=>$xw,
      OB=>$obs,
      NM=>$name,
      SEE=>$see
    };
    push(@lineout,$x);
  }
  @lo2 = sort {$a->{JD}<=>$b->{JD}} @lineout;
  foreach $l (@lo2) {
    $jd=$l->{JD};
    $g=$l->{G};
    $s=$l->{S};
    $W=$l->{W};
    $kcount=$l->{KC};
    $logcount=$l->{LC};
    $logkcount=$l->{LK};
    $xw=$l->{XW};
    $obs=$l->{OB};
    $name=$l->{NM};
    $see=$l->{SEE};
    printf X "%10.4f %4i %4i %4i %7.2f %6s %6s %5.3f %-4s %-20s   | %s\n",$jd,$g,$s,$W,$kcount,$logcount,$logkcount,$xw,$obs,$name,$see;
  }
  close(X);
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

sub old_solarjd {
  $day=$_[0];
  $month=$_[1];
  $year=$_[2];
  $ut=$_[3];
  $dtime0=julian_zero($month,$year);
  $nhour=substr($ut,0,2);
  $nmin=substr($ut,2,2);
  $dday=((60.*$nhour)+$nmin)/1440.;
  $dday=$dday+$day+$dtime0-2400000.5;
  return $dday;
}

sub julian_zero {
# This is the old JULIAN0 quickbasic routine....
  @pppp=(0,0,31,28,31,30,31,30,31,31,30,31,30,31);
  $sum=0;
  foreach $pp (@pppp) {
    $sum+=$pp;
    push(@nmon,$sum);
  }
  $nmo=$_[0];
  $nyear=$_[1];
  $nyr=$nyear;
  if($nyr < 100) {$nyr+=2000;}
  $nyr-=1601;
  $dtime=2305813;
  while($nyr >= 400) {
    $nyr-=400;
    $dtime+=146097;
  }
  while($nyr >= 100) {
    $nyr-=100;
    $dtime+=36524;
  }
  while($nyr >= 4) {
    $nyr-=4;
    $dtime+=1461;
  }
  $dtime+=(365*$nyr) + $nmon[$nmo];
  if($nyr==3 && $nmo>2) {$dtime+=1;}
  return $dtime;
}
