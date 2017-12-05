#!/usr/bin/perl
#       This program is free software; you can redistribute it and/or modify
#       it under the terms of the GNU General Public License as published by
#       the Free Software Foundation; either version 2 of the License, or
#       (at your option) any later version.
#       
#       This program is distributed in the hope that it will be useful,
#       but WITHOUT ANY WARRANTY; without even the implied warranty of
#       MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#       GNU General Public License for more details.
#       
#       You should have received a copy of the GNU General Public License
#       along with this program; if not, write to the Free Software
#       Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston,
#       MA 02110-1301, USA.
#     
#       Author: Saif Ahmed
#       Contact: saiftynet{at}gmail{dot}com
#		Please report bugs to me at above email adress.
#       FileName: piStatus.pl

 $shellPassword="secret";     # shell command execution requires a password...set it here
 $scriptsPath="scripts/";     # IMPORTANT Change this to the path of
                              # scripts from document root.
                              # This folder needs to be writeable by www-data or
                              # whatever the web server userID is .
 
 #######################Nothing below this needs to be changed#############################
 ###########################################################################################
 $version = "0.14";
 
 #check installed modules
  eval "use CGI"; $hasCGI = $@ ? 0 : 1;
  eval "use CGI::Carp"; $hasCarp = $@ ? 0 : 1;
  if ($hasCarp)   {use CGI::Carp qw(fatalsToBrowser);}
  $hasGpio=(`which gpio`=~m/gpio/)? 1:0;
  $hasI2c=(`which i2cdetect`=~m/i2cdetect/)? 1:0;;
  $hasVc=(`which /opt/vc/bin/vcgencmd`=~m/vcgencmd/)? 1:0;
  $hasWWW=(`ping www.windon.themoon.co.uk -c 1 | grep rtt`=~m/rtt/)? 1:0; 
  $hasGears=(`ls ../cgi-bin/ | grep piGears.pl`=~m/piGears/)?1:0;
  $hasSio=(`ls ../cgi-bin/ | grep piStashIO.pl`=~m/piStashIO/)?1:0; 

 $reqURI = $ENV{'REQUEST_URI'};
 $host = $ENV{'HTTP_HOST'};
 $docRoot = $ENV{'DOCUMENT_ROOT'};
 $visitorIP = $ENV{'REMOTE_ADDR'}; ##REMOTE_HOST in some systems;
 $scriptFolder=$docRoot."/".$scriptsPath;$scriptFolder=~s/\/\//\//;
 $scriptFolderURL="http://".$host."/".$scriptsPath;   
 $Parameters=$reqURI?$reqURI:join(":",@ARGV);
 $Parameters=~s/^([^\?]*)\?//;
 $piStatusScript=$1?$1:$reqURI;
 $timeStamp=time();
 $ReadableTime = localtime($timeStamp);
  setStyles();  # this uses either built in CSS defaults or a premade piStatus.css in scripts folder
  lastIPs(20);
 
# make a scripts folder if not already available

    if (! -e $scriptFolder ){
		$hasDir= mkdir $scriptFolder  ;
		if(!$hasDir){$hasDir.=$!};
	}
	else {$hasDir="Yes"}


# Following lines determine whther piStaus was called from the command line, 
# or a browser. Parameters also depend on whether form POST or GET was used
# and whether CGI.pm is installed...
$argLength=@ARGV;
if ($argLength>0){
	$command=$ARGV[0];
	$file=$ARGV[1];
	$data=$ARGV[2];
	
}
elsif (!$hasCGI){
  if (length ($ENV{'QUERY_STRING'}) > 0){
      $buffer = $ENV{'QUERY_STRING'};
      @pairs = split(/&/, $buffer);
      foreach $pair (@pairs){
           ($name, $value) = split(/=/, $pair);
           $value =~ s/%([a-fA-F0-9][a-fA-F0-9])/pack("C", hex($1))/eg;
           $in{$name} = $value; 
      }
 }

  $command=$in{"command"};
  $file=$in{"file"};
  $data=$in{"data"};
  $debug=$in{"debug"};
  $formMethods="fm.method=\"get\";";
}
else {
  $query=new CGI; 
  $command=$query->param("command");
  $file=$query->param("file");
  $data=$query->param("data");	
  $debug=$query->param("debug");
  $formMethods=	"fm.method=\"post\";\nfm.enctype=\"multipart/form-data\";";
  $Parameters.="   command=$command file=$file data=$data";
}

  $debug=$debug?1:0;
  $debugScript =$debug?"<div  class=debug>Has CGI= $hasCGI,  Has CGI::Carp=$hasCarp,<br>".
         "Gpio installed=$hasGpio, Has Directory = $hasDir, Has vcgencmd=$hasVc<br>".
         "Command =$command Arg1=$file Arg2=$data<br>".
         "ReqURI=$reqURI</div>":"";

#detect board revision
    $RevCode=`cat /proc/cpuinfo | grep Revision`;
    $RevCode=~s/[^0-9]//g;
    if ($RevCode  eq "0002") {$Board="Model B Revision 1.0"} 
    elsif ($RevCode  eq "0003") {$Board="Model B Revision 1.0 + ECN0001 (no fuses, D14 removed)"}
    else {$Board="Model B Revision 2.0"};
    
if ($RevCode=~m/0002|0003/){
	@gpioPins=(0, 1, 4, 7, 8, 9, 10, 11, 14, 15, 17, 18, 21, 22, 23, 24, 25);
	@pinDefs=   ("3V3","5V0","00G","DNC","01G","GND","04G","14G","DNC","15G","17G","18G","21G","DNC","22G","23G","3V3","24G","10G","DNC","09G","25G","11G","08G","DNC","07G");
	@pinAltDefs=("3V3","5V0","IDA","DNC","ICL","GND","04G","TXD","DNC","RXD","17G","18G","21G","DNC","22G","23G","3V3","24G","SM1","DNC","SM0","25G","SCK","SC0","DNC","SC1");
}
else {
	@gpioPins=(2, 3, 4, 7, 8, 9, 10, 11, 14, 15, 17, 18,  22, 23, 24, 25, 27);
	@pinDefs=   ("3V3","5V0","02G","DNC","03G","GND","04G","14G","DNC","15G","17G","18G","27G","DNC","22G","23G","3V3","24G","10G","DNC","09G","25G","11G","08G","DNC","07G");
	@pinAltDefs=("3V3","5V0","00G","DNC","01G","GND","04G","14G","DNC","15G","17G","18G","21G","DNC","22G","23G","3V3","24G","10G","DNC","09G","25G","11G","08G","DNC","07G");
}
    
	@gpioData=split("\n",loadFile(".gpioFile"));

 
 $status="";
     if ($command eq ""){
		 $status=about();
	 }
     elsif ($command =~m/^list/){
         $status = listScripts($file);
     }
     elsif ($command =~m/^cd/){
         $status = listScripts($file);
     }
     elsif ($command eq "edit"){
		 $status = editFile($file);
	 }
	 elsif ($command eq "view"){
		 $status = viewFile($file);
	 } 
     elsif ($command eq "new"){
         $status = newFile($file,$data);
     }
     elsif ($command eq "del"){
         $status = delFile($file);
     }
     elsif ($command eq "ren"){
         $status = renFile($file,$data);
     }
     elsif ($command eq "run"){
         $status = runFile($file);
     }    
     elsif ($command eq "save"){
		 $data=~s/%([0-9a-f]{2})/ chr hex $1 /egi; 
		 $status = saveFile($file,$data);
	 }
	 elsif ($command eq "upload"){ 
		 $status = upload($file);
	 }
	 elsif ($command eq "shell"){
		 $status=shellCommand($file,$data,1);
	 }
	 elsif ($command eq "gpio"){ 
		if ($hasGpio) {
			saveLogs(".gpioCommands.log",$timeStamp."-".$file);
			$status = gpio($file,$data);}
		else {$status = toTable("GPIO","wiringPi appears not be installed...<br>".
	            "See <a href='http://www.windon.themoon.co.uk/NVSM/WebControl#Requirements'>Requirements</a>".
	             "<br> Get it from <a href='https://projects.drogon.net/raspberry-pi/wiringpi/'> here</a>");
	             }
	 }
	 elsif ($command eq "sio"){
		 $status=sio();
	 }
	 elsif ($command eq "i2c"){ 
		if ($hasI2c) { $status = i2c($file,$data)}
		else {$status = toTable("I2C","i2c-tools appear not be installed...<br>".
	            "See <a href='http://www.windon.themoon.co.uk/NVSM/WebControl#Requirements'>Requirements</a>");
	         }
	 }
	 elsif ($command eq "pins"){ 
		if ($hasGpio) {pinStates($file,$data);}
	 }
	 elsif ($command eq "chart"){ 
		if ($hasGpio) {
			$status=gpioChart($file);
			}
	 }	       
	 elsif($command eq "stats"){
		 if ($file eq "m"){
			 $stats = memStats();
		 }
		 elsif ($file eq "i"){
			 $stats = ipStats();
		 }
		 elsif ($file eq "c"){
			 $stats = top();
         }
         elsif ($file eq "o"){
			 $stats = modules();
         }
         elsif ($file eq "p"){
			  $stats = taskMan();
         }
         elsif ($file eq "k"){
		      `kill $data`;
		      $stats= taskMan()
	 }
         elsif ($file eq "u"){
			 $stats = usb();
         }
         elsif ($file eq "v"){
			 $stats = vcgencmd();
         }
         elsif ($file eq "d"){
			 $stats = shellCommand($shellPassword,"dmesg | tail",0);
         }
          elsif ($file eq "h"){
			 $stats = hardware();
         }
         elsif ($file eq "e"){
			 $stats = env();
         }
         elsif ($file eq "s"){
			 $stats = diagnostics();
         }
         else {
			 $stats = top();
         };
         
$status = <<END_Menu;
<table class=stMenu><tr><td valign=top>
<div class=stMenu>
<a class=btn onclick=piStatus('')>About</a>
<a class=btn onclick=piStatus('stats','c')>System</a>
<a class=btn onclick=piStatus('stats','s')>Diagnostics</a>
<a class=btn onclick=piStatus('stats','e')>ENV</a>
<a class=btn onclick=piStatus('stats','m')>Memory</a>
<a class=btn onclick=piStatus('stats','u')>USB</a>
<a class=btn onclick=piStatus('stats','i')>Network</a>
<a class=btn onclick=piStatus('stats','o')>Modules</a>
<a class=btn onclick=piStatus('stats','h')>CPU Info</a>
<a class=btn onclick=piStatus('stats','p')>Processes</a>
<a class=btn onclick=piStatus('stats','v')>vcgencmd</a>
<a class=btn onclick=piStatus('stats','d')>dmesg</a>
</div>
</td><td valign=top>$stats</td></tr></table>
END_Menu

}

if ($status eq "") {
	$status="piStatus exited without report<br>";
	$status.="Parameters=$Parameters<br>";
	$status.="reqURI=$reqURI<br>";
	$status.="scriptFolder=$scriptFolder<br>";
	$status.="Errors=$errors<br>";
	unless ($hasGpio) {$status.= "<br>wiringPi appears not to be installed"};
	}

sub gpioChart{
	my $mode=shift;
	my @chartArray=();
	my $pinCount=@gpioPins;

	my $gpioLogFile=loadFile(".gpioLogs");
	my @lines=split("\n",$gpioLogFile);
	my $lineCount=@lines;
	if (!$mode){
		my $csv="Time,Pin ".join(",Pin ",@gpioPins)."\n";
		for (my $lc=$lineCount-1;$lc>-1;$lc--){
			my ($timeStamp,$rest)=split("-",$lines[$lc]);
			my $time=localtime($timeStamp);
			$rest=~s/\:/\,/g;$rest=~s/[^\d\,]//g;
			$csv.="$time,$rest\n";
		}
		saveFile("gpioLogs.csv",$csv);
		print "Location: ".$scriptFolderURL."gpioLogs.csv\n\n";
		exit 1;
	}
	
	for (my $lc=0;$lc<$lineCount;$lc++){
		my ($timeStamp,$rest)=split("-",$lines[$lc]);
		my $time=localtime($timeStamp);
		#$time=~s/[^a-z0-9\s\:]//ig;
		my @cells=split(":",$rest);
		for (my $pc=0;$pc<$pinCount;$pc++){
			my $state=($cells[$pc]=~m/1/)?"on":"off";
			$cells[$pc]="<td  onmouseout='divText(\"pinTime\",\"..\")' onmouseover='divText(\"pinTime\",\"..GPIO pin:".$gpioPins[$pc]." Time: $time State:$state\")' class='bar $state'></td>"
		}
		$chartArray[$lc]=[@cells];
	}
	
	my $chartTable="<tr>".("<td>.</td>" x ($lineCount+1))."</tr>";
	for (my $pc=0;$pc<$pinCount;$pc++){
		$chartTable.="<tr><td class=fCell>Pin ".$gpioPins[$pc]."</td>";
		for (my $lc=$lineCount-1;$lc>-1;$lc--){
			$chartTable.=$chartArray[$lc][$pc];			
		}
		$chartTable.="</tr>\n";
	}

	return  toTable("GPIO Charted","<table class=chart>$chartTable</table><div class=psStatus id=pinTime>..</div>");
}

sub gpio{
	my $tmp=shift;
	my %submissions=();
	my @submits=(); my $All=1;
	if ($tmp eq "init"){
		for (my $count=0;$count<@gpioPins;$count++){
			$submissions{$gpioPins[$count]}=join(":",($gpioPins[$count],"in","up",""));
		}
	}
	elsif ($tmp eq "Table"){
		$All=0;
	}
	elsif ($tmp eq "clear"){
		saveFile(".gpioLogs",$data);
	}
	else{ 
		@submits=split("\n",$tmp);
		foreach(@submits){
			my $line = $_;
			$line=~s/:.*$//;
			$submissions{$line} = $_;
		}
	}
	
	my $pinLogLine=$timeStamp."-";
	my $newTable="";
	# my @execArray=();
	for (my $count=0;$count<@gpioPins;$count++){
		my ($pnl,$mdl,$ctl,$dtl)=split(":",$gpioData[$count]);
		$pnl=$gpioPins[$count];
		if ($submissions{$pnl}){ # if there has been a submission
			my ($pns,$mds,$cts,$dts)=split(":",$submissions{$pnl});
			if (($mdl ne $mds)&&($mds=~m/in|out|pwm/)){
				$mdl=$mds;
				`/usr/local/bin/gpio -g mode $pnl $mds`;
				#push (@execArray,"/usr/local/bin/gpio -g mode $pnl $mds");
			};  #set new mode
			if (($ctl ne $cts)&&($cts=~m/up|down|tri/)){
				$ctl= $cts;
				`/usr/local/bin/gpio -g mode $pnl $cts`;  #set new control
				#push (@execArray,"/usr/local/bin/gpio -g mode $pnl $cts");
			}
			if ($mdl eq "out"){
				$dtl=$dts;
				`/usr/local/bin/gpio -g write $pnl $dts`;
				#push (@execArray,"/usr/local/bin/gpio -g write $pnl $dts");
			}
			elsif ($mdl eq "pwm"){
				$dtl=$dts;
				 `/usr/local/bin/gpio -g pwm $pnl dts`;
				#push (@execArray,"/usr/local/bin/gpio -g pwm $pnl dts");
			}
		}
		if ($mdl eq "in"){
				$dtl = `/usr/local/bin/gpio -g read $pnl`;
		}
		$pinLogLine.=(($dtl=~m/\d+/)?$dtl:"?").":";
		$gpioData[$count]=$pnl.":".($mdl?$mdl:"?").":".($ctl?$ctl:"?").":".$dtl;
		$gpioData[$count]=~s/[\n\r]//g;
		if ($All){ $newTable.="<tr><td>".$pnl."</td><td x=1 onclick=setValues($pnl,this,1)>".($mdl?$mdl:"?").
		                           "</td><td x=2 onclick=setValues($pnl,this,2)>".($ctl?$ctl:"?").
		                           "</td><td x=3 onclick=setValues($pnl,this,3)>".(($dtl=~m/\d+/)?$dtl:"?")."</td></tr>\n";
		                           }
	}
	if ($All){$newTable.="<tr><td colspan=4><span class='btn right' onclick='piStatus(\"gpio\",gpioMods.join(\"\\n\"))'>Submit</span>".
	                     "<span class='btn right' onclick=piStatus('gpio')>Reset</span>".
	                     "<span class='btn right' onclick=piStatus('gpio','init')>Initialise</span></td></tr>";}
	$gpioJS="gpioArray=new Array(\"".join("\",\"",@gpioData)."\")";
	saveFile(".gpioFile",join("\n",@gpioData));
	$pinLogLine=~s/[\s\n]//g;
	#Only save to log if the data has changed;
	my $lastEntry=lastLogEntry(".gpioLogs");
	if ( (split("-",$pinLogLine))[1] ne (split("-",$lastEntry))[1]  ){
		saveLogs(".gpioLogs",$pinLogLine);
	}
	if ($All){$newTable="<tr><th>IO</th><th>Mode</th><th>Control</th><th>Data</th><td rowspan=".(@gpioPins+2)."><br><center>".gpioTable()."<br>".
	          "<div style=\"width:12em;clear:both\"><span class=\"btn left\" onclick=popOut('command=pins')>Pop Out</span>".
	          "<span class=\"btn left\" onclick=popOut('command=chart&file=0')>Export CSV</span></div>".
	          "<div style=\"width:12em;clear:both\"><span class=\"btn left\" onclick=piStatus('chart','1')>Chart</span>".
	          "<span class=\"btn left\" onclick=\"piStatus('gpio','clear','$lastEntry')\">Clear Logs</span></div></center></td></tr>".$newTable;
	          return toTable("GPIO State",$newTable );
		  }
    else {return gpioTable()};
}

sub gpioTable{
	my $pins="<table class=gTable>";
	for (my $rw=1;$rw<14;$rw++){
		$pins.=makeRow($rw);
	}
	return $pins."</table>";

	
sub makeRow{
	my $rw=shift;
	my $row="<tr>";
	for (my $col=0;$col<4;$col++){
		$row.=makeCell($rw,$col);
	}
	return $row."</tr>";
}
	
sub makeCell{
	my ($rw,$col)=@_;
	my $colCell="<td class=";
		if (($col>0)&&($col<3)){
			my $class="pin ";
			my ($mode,$state)=split(":",mapPin($rw*2-2+$col));
			if ($state eq "1"){$class.="on";}
			elsif ($state eq "0"){$class.="off";}
			elsif ($state =~m/3V3|5V0/){$class.="power";}
			elsif ($state eq"GND"){$class.="ground";}
			else {$class.="undefined";};
			$colCell.='"'.$class.'">';
			$colCell.= ($state eq "DNC")? "X":"*";			
		}
		else {
			$colCell.="label>";
			if ($col==1) {$colCell.=" style=\"align:right\">"};
			$colCell.=$pinDefs[$rw*2-($col?0:1)-1];
		}
		return $colCell."</td>";
}

sub mapPin{
	my $no=shift;
	$no--;
	if ($pinDefs[$no]=~m/(\d\d)G/) {
		my $gpio=$1; my $found=0;my $index=0;my $gpioLength=@gpioData;
		foreach (@gpioData){
			my ($pnl,$mdl,$ctl,$stl) = split(":",$_);
			if ($pnl == $gpio){return $mdl.":".$stl}
			
		}
		return "error:0" ;
	}
	else {
		return "fixed:".$pinDefs[$no];
	}
}

}

sub pinStates{
	my($refresh,$plot)=@_;
	$refresh=$refresh?$refresh:5;
	my $pinTable=gpio("Table");
	
	print <<END_HTML;
Content-Type: text/html; charset=UTF-8

<HMTL><head>
<meta http-equiv="refresh" content="$refresh" > 
$styleLine
</head><BODY>$pinTable</BODY></HTML>
END_HTML

exit 1;	
}

sub i2c{
	my ($addr,$i2cCom)=@_;my $detected="";my ($bs,$ad)=split(":",$addr);
	my $name=i2cInfo($addr,"NAME");
	if ($name eq $addr){ $name =""}
	if ($i2cCom eq "view"){
		return toTable("Viewing device $addr (".$name.")",viewDevice() );
	}
	elsif($i2cCom =~m/^([gs]et)(.*)$/){
		$i2cCom="i2c$1 -y $bs 0x$ad $2  2>&1"; my $req="\U$1";  # why is 2>&1 needed in this an th ` ` ?
		my $res=`$i2cCom  2>&1`; $res=~s/\n/<br>/g;	$res=~s/\s/&nbsp;/g;
		return toTable("Viewing device $addr (".$name.")",viewDevice()."<div class=shell>$req request :- <i> $i2cCom</i><hr>Response is: -<br>$res</div>");
	}
	elsif($i2cCom =~m/^mod(.*)$/){
		return toTable ("Modifying $1 for Device <i>$addr </i>".
	    "<a class=\"btn right\" onclick=\"piStatus('i2c','$addr','upd$1:'+encodeURIComponent(document.getElementById('editFile').value) )\">Update</a>",
	    "<textarea id=editFile rows=10 cols=30>".i2cInfo($addr,$1)."</textarea>");
	}
	elsif($i2cCom =~m/^upd([^:]*):(.*)$/){
		my $req=$1; my $inf=$2;
		i2cInfo($addr,$req,$inf);
		return i2c($addr,"view");
	}
	else{
		foreach(0,1){
			my $res = `i2cdetect -y $_`;
			$res=~s/^.*\n/\n/;
			$res=~s/\n\d0\://g;
			$res=~s/\s*--//g;
			$res=~s/^\s*(\S)/$1/g;$res=~s/(\S)\s*$/$1/g;
			#
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			
			$res.=" 77". ($_?" 36":"");
			if ($res ne ""){
				$detected.=addToBtn($_,$res);}
			else{$detected.="Bus $_: No Devices found <br>";}
		}
		return toTable("Detected I2C devices","<div class=fileList>".$detected."</div>");
	}
	
	sub viewDevice{
		return "<div class=fileList><span><b>Device Label: </b>".i2cInfo($addr,"NAME")."</span><span class='btn right' onclick=\"piStatus('i2c','$addr','modName')\">Edit Name</span></div>".
		      "<div class=fileList><span><b>Info</b></span><span class='btn right' onclick=\"piStatus('i2c','$addr','modINFO')\">Edit Info</span></div>".
		      "<div class=fileList>".rawToView(i2cInfo($addr,"INFO"),0)."</div><hr>".
		      "<i>i2cget -y $bs 0x$ad </i><input id=i2cget><a class=\"btn right\" onclick=\"piStatus('i2c','$addr','get'+document.getElementById('i2cget').value )\">get</a><br>".
		      "<i>i2cset -y $bs 0x$ad </i><input id=i2cset><a class=\"btn right\" onclick=\"piStatus('i2c','$addr','set'+document.getElementById('i2cset').value )\">set</a><br>";
		
	}
	
	sub addToBtn{
		my ($bus,$addrs)=@_;
		my @address=split(" ",$addrs);my $result="";
		foreach (@address){
			if ($_=~m/([\da-f]{2})/){
				$result.="<span class='btn left' onclick=\"piStatus('i2c','$bus:$1','view')\">".i2cInfo("$bus:$1","NAME")."</span>";
			}
		}
		return $result;		
	}
}

sub i2cInfo{
	my ($addr,$req,$inf)=@_; my %infoLine=();
	$req="\U$req";
	my @infLines=split("\n",loadFile("I2CDevices.inf"));
	my @devices=();
	my $current="";my $lostAddr=0;my $foundAddr=0;my $count=0;my $foundKey=0;my $value="";
	while ((!$lostAddr) && (!$foundKey)&& ($count<@infLines)){
		if (@infLines[$count]=~m/\[([10]:[0-9a-f]{2})\]/) {
			if ($1 eq $addr){$foundAddr=1}
			else {
				if ($foundAddr){$lostAddr=1}
			}
		}
		elsif ($foundAddr && (@infLines[$count]=~m/^([^=]*)=(.*)$/)){
			if ($1 eq $req){$value=$2;$foundKey=1};
		}
		$count++;
	}
	if ($foundKey){
		if (!$inf){
			$value=~s/%([0-9a-f]{2})/ chr hex $1 /egi; 
			return $value;
		}
		@infLines[$count-1] = "$req=$inf";
	}
	else{
		if (!$inf){
			return ($req eq "NAME")?$addr:"$req for $addr not found";	
		}
		splice (@infLines,$count-1,0,"$req=$inf"); #insert where it gave up 
		if(!$foundAddr){ # if device was not stored,  insert label at same place
			splice (@infLines,$count-1,0,"[$addr]");
		}
	}
	saveFile("I2CDevices.inf",join("\n",@infLines));
		
}

sub shellCommand{
	my ($pw,$shCom,$next)=@_;
	my $method= $hasCGI?" method=post ": " method=get ";
	my $form="<div style=\"width:30em;clear:both\"><form $method>";
	my $history="";
	if ($pw ne $shellPassword){$form.="Password:&nbsp;<input type=password name=file><br>";}
	elsif ($next) {
		$history="<div class=history onclick='document.getElementById(\"shellCommand\").value=this.innerHTML'>".$shCom."</div>";
		$form.="<input type=hidden name=file value=$shellPassword>";
		my @prev=split("\n",loadFile(".shellCommands.log"));
		foreach (@prev){
			my ($time,$IP,@com)=split("-",$_);
			if ($IP eq $visitorIP){
				$history.="<div class=history onclick='document.getElementById(\"shellCommand\").value=this.innerHTML'>".join("-",@com)."</div>"
			}
		}
	};
	$form.="<input type=hidden name=command value=shell>Command:<input id=shellCommand name=data><input class=\"btn right\" type=submit value=Go></form></div>";
	if ($pw eq "undefined" ){return toTable("Shell Mode Login",
	          "Access to system shell requires user to login. <br>".
	          "Note that this is potentially dangerous and can damage <br>".
	          "the system.  Should only be used with care. Interactive<br>".
	          " commands can not be used, and for security reasons,<br>". 
	          " certain functions are blocked.<br><br> $form")};
	if ($pw ne $shellPassword){ return toTable("Authetication Failure","Command execution can not continue.<br>$form")}
	
	if ($shCom=~m/chmod|sudo|cgi-bin/){
			saveLogs(".shellCommands.log",$ReadableTime."-".$visitorIP."-".$shCom."-BLOCKED");
			return toTable("Executing Shell Command - <em>".$shCom."</em> Blocked","Command execution blocked because<br>script may potentially compromise system");
	}
	saveLogs(".shellCommands.log",$ReadableTime."-".$visitorIP."-".$shCom);
	
	my $res=`cd $scriptFolder && $shCom 2>&1`;
	$res=~s/\n/<br>/g;
	$res=~s/\s/&nbsp;/g;
	return toTable("Executing Shell Command - <em>".$shCom."</em><br>".($next?$form:""),(($history ne"")?"<div class=shellHistory>".$history."</div>":"")."<div class=shell>".$res."</div>");
}


sub getExt{
	my $file=shift;
	if( $file=~m/\.(txt|htm|html|scr|pgl|jpg|png|gif)$/i){
		return $1;
	}
	else {return 0;}
}

sub getPath{
	my $dir=shift;
	$dir=~ s/([^\/]*)$//;
	$dir=~s/\/$//;
	return $dir;	
}

sub pToBC{ #bread crumb generator
	my $list=shift; my $subDir=shift;my $bCr="";
	if ($subDir && ($subDir ne "undefined")){
		$subDir=~s/\/\//\//g; #replace double slashes with single
		my @bc=split("/",$subDir); my $sp=""; my $current="";
		if ($list){
			$current="<span class=\"unBtn left\">".pop(@bc)."</span>";
		}
		$bCr.="<a class=\"btn left\" onclick=\"piStatus('list')\">scripts</a>";
		foreach (@bc){
			$sp.=$_;
			$bCr.="<a class=\"btn left\" onclick=\"piStatus('list','$sp')\">$_</a>";
			$sp.="/";
		}
		$bCr.=$current;
		return $bCr;
	}
	else {return $list?"<span class=\"unBtn left\">scripts</span>":"<a class=\"btn left\" onclick=\"piStatus('list')\">scripts</a>"}
}

sub listScripts{
	my $subDir=shift; my @scripts=();
	if (($subDir=~m/[a-z]/)&&(-d $scriptFolder.$subDir)){
		@scripts=<$scriptFolder$subDir/*>;
	}
	else {@scripts=<$scriptFolder*>;$subDir=""};
	
	my $list="<div class=fileList><div style=\"float:left\"><input size=20 id=newFile></div><a class=\"btn right\" onclick=newFile(\"$subDir\",0)>New File</a><a class=\"btn right\" onclick=newFile(\"$subDir\",1)>New Dir</a></div>\n";
	if ($hasCGI){
		$list.="<div class=fileList><form id=uploadForm method=post enctype=\"multipart/form-data\"><input type=hidden name=command value='upload'><div style=\"float:left\"><input type=file name=file id=uploadFile></div><a class=\"btn right\" onclick=upload()>Upload File</a></form></div>\n";
	}
	foreach $file (@scripts){
		if (-d $file){
			$file=~s/$scriptFolder//;
			$list.="<div class=fileList ><div class=folder>$file (Directory) </div><a class=\"btn right\" onclick=\"piStatus('del','$file')\">Del</a><a class=\"btn right\" onclick=\"piStatus('cd','$file')\">Open</a></div>";
		}
		else {
			my %opt=('e'=>0,"v"=>1,"d"=>1,"x"=>0);
			my $filesize = -s $file;
			$file=~s/$scriptFolder//;
			my $ext=getExt($file);
			if (($ext eq "0")||($ext=~m/txt|htm[l]?|pgl/i)) {$opt{"e"}=1};
			if ($ext =~m/pgl|scr/){$opt{x}=1};
			
			$list.="<div class=fileList ><div class=file>$file ($filesize) </div>".
		       "<a class=\"btn right\" onclick=\"rename('$file')\">Ren</a>".
		       ($opt{"d"}?"<a class=\"btn right\" onclick=\"piStatus('del','$file')\">Del</a>":"").
		       ($opt{"v"}?"<a class=\"btn right\" onclick=\"piStatus('view','$file')\">View</a>":"").
		       ($opt{"e"}?"<a class=\"btn right\" onclick=\"piStatus('edit','$file')\">Edit</a>":"").
		       ($opt{"x"}?"<a class=\"btn right\" onclick=\"piStatus('run','$file')\">Exec</a>":"").
		       
		       "</div>\n";
		   }
	}
	return toTable(pToBC(1,$subDir),$list);
}


sub newFile{
	my ($file,$type)=@_;
	if ($file =~m/[^\.][a-z0-9\.]*/){
		if ($type =~m/file/i){
			saveFile($file,"");
			editFile($file);
		}
		elsif ($type =~m/directory/i){
			if (-d $scriptFolder.$file){
				return toTable("Attempt to create $type - <em>".$file."</em> Blocked","Directory already exists");
			}
			else{
				mkdir $scriptFolder.$file || return toTable("Attempt to create $type - <em>".$file."</em> Failed","$!");
				return listScripts($file);
			}

		}
	}
	else{
		return toTable("Attempt to create $type - <em>".$file."</em> Blocked","Filename contains invalid characters or<br>or may be hidden");
	}
}

sub editFile{
	my $file=shift;
	my $data=loadFile($file);
	$data=~s/&/&amp;/g;
	$data=~s/</&lt;/g;
	return toTable (pToBC(0,getPath($file))."Editing file <i>$file </i>".
	    "<span>&nbsp;&nbsp;</span>".
	    "<a class=\"btn right\"   onclick=piStatus('save','$file',encodeURIComponent(document.getElementById('editFile').value))>Save</a>".
	    "<a class=\"btn right\"   onclick=\"piStatus('save',prompt('Enter File Name','$file'),encodeURIComponent(document.getElementById('editFile').value))\">Save As</a>",
	    "<textarea id=editFile rows=20 cols=100>$data</textarea>");
}

sub viewFile{
	my $file=shift;
	my $ext=getExt($file);
	if ($ext =~m/htm[l]?/i){ return toTable("Displaying WebPage - <em>".$file."</em>",
	   "<iframe src=$scriptFolderURL$file>Please wait...</iframe>")}
	elsif ($ext =~m/jpg|gif|png/i){ return toTable("Displaying Image - <em>".$file."</em>",
	   "<img width=100 src=$scriptFolderURL$file>")}	
	my $data=loadFile($file);
	if ($ext =~m/scr/i){
		while ($data =~m/<b(\d+)>/){
			my $indent="&nbsp;&nbsp;" x $1;
			$data =~s/<b$1>/$indent/g;
			}
		}
	$data=rawToView($data);
	my $exec= (getExt($file)=~m/htm[l]?|pgl|scr/) ?"<a class=\"btn right\" onclick=\"piStatus('run','$file')\">Exec</a>":"";
	return toTable (pToBC(0,getPath($file))."&nbsp;Viewing&nbsp;file&nbsp;<em>$file</em>&nbsp;&nbsp;&nbsp;$exec", $data);
}

sub loadFile{
	my $file=shift;
	my $row="";
	open (FILE,"<$scriptFolder$file") || return "Error: -Can't load  $scriptFolder$file $!";
	while (<FILE>){
		$row.=$_;
	}
	close FILE;
	return $row;
}

sub delFile{
	my $file=shift;
	if (-d $scriptFolder.$file){rmdir $scriptFolder.$file;}
	else {unlink $scriptFolder.$file;}
	listScripts(getPath($file));
}

sub renFile{
	my ($file,$newName)=@_;
	$newName=~s/^\.//;#do not allow rename to hidden
	rename($scriptFolder.$file,$scriptFolder.$newName) || return toTable(pToBC(0,getPath($file))."Rename Failed", "Unable to rename  $file to  $newName<br>$!");
	listScripts(getPath($file));
}


sub saveFile{
	my ($file,$data)=@_;
	open (FILE,">$scriptFolder$file") || return toTable("SAVE","Can't create  $scriptFolder$file $!");
	print FILE $data;
	close FILE;
	my $ext=getExt($file);
	my $options="<span class=\"btn right\" onclick=\"piStatus('edit','$file')\">Edit $file</span>";
	if ($ext =~m/pgl|scr/i) { $options.="<span class=\"btn right\" onclick=\"piStatus('run','$file')\">Exec</span>"}
	return toTable(pToBC(0,getPath($file))."SAVE",($data eq "")?"Empty File $file Created/Saved":"File <em>$file</em> saved successfully <br>$options");
}

sub upload {
	$fileName=shift;
    if ($hasCGI){
       unless ($upload_filehandle =  $query->upload("file")) {
                       return toTable("Upload Failed","Unable to get handle $file for $fileName $!");}
       $fileName =~ s/.*[\/\\](.*)/$1/;
       open UPLOADFILE, ">$scriptFolder$file" or return toTable("Upload Failed","Cant create upload file name $fileName in $scriptFolder $!; ");
       # binmode UPLOADFILE;
       while ( <$upload_filehandle> ) {print UPLOADFILE;} close UPLOADFILE;
       return toTable("File uploaded successfully","File $fileName uploaded successfully");
     }
     else { return toTable("CGI.pm not installed","piStatus requires perl module CGI to be installed");}
}

sub runFile{
    my $file=shift;
    my $ext=getExt($file);
	if ($ext =~m/htm[l]?/i){ return toTable("Displaying WebPage - <em>".$file."</em>",
	   "<iframe src=$scriptFolderURL$file>Please wait...</iframe>")}
    elsif($ext =~m/pgl|scr/i) {
		my $pgl=`piGears.pl run $file`;
		return  $pgl;
	}
    else { return  toTable("Unable to Execute - <em>".$file."</em>",
	   "Unable to execute file<br>Configuration error")};
}


sub decodeURL {
  $_ = shift;
  tr/+/ /;
  s/%(..)/pack('c', hex($1))/eg;
  return($_);
}

sub ipStats{
  my @ipRows=`ip -o addr`;
  foreach (@ipRows){
	$_=~s/(\d+):\s(eth\d|lo|wlan\d|vboxnet\d):\s*<(.*)>(.*)\\\s*link\/(loopback|ether)\s([^\s]*).*\n/<tr><th valign=top><br>Interface $1<\/th><td><br>Name: $2<br>Status: $3<br> Info: $4 <br> Type : $5<br> MAC Address: $6<\/td><\/tr>/g;
    $_=~s/(\d+):\s(eth\d|lo|wlan\d|vboxnet\d)\s*inet([6]?)\s([^\/]*).*\n/<tr><td><\/td><td>Inet$3 IP Address: $4<\/td><\/tr>/g;
    }
    my $ipStatus=join("",@ipRows);
    
    return toTable("Network Status" ,"<tr><td colspan=2>piStatus can".($hasWWW?"":" not")." connect to the Internet</td></tr>".$ipStatus);
    
}

####System Tab

sub top{
  my $top=`top -b -n 1`;
  $top =~s/[^\s\.\:a-zA-z0-9\-]//g;
  my @lines=split("\n",$top);

  $lines[0]=~s/top(.*)up(.*)(\d)[^\d]+user(.*)load average:\s(.*)/<tr><td width=200 align=center>Current Time:$1<br>Load Average: $5<\/td><td align=center>Uptime: $2 <br>Connected Users: $3<\/td><\/tr>/;
  $lines[1]=~s/^Tasks\:([\d\s]*)\stotal([\d\s]*)\srunning([\d\s]*)\ssleeping([\d\s]*)\sstopped([\d\s]*)\szombie/<tr><td align=center><em>Tasks<\/em>&nbsp;&nbsp;Total: $1<br>Running: $2<br>Sleeping: $3<br>Stopped: $4<br>Zombie: $5<br><\/td>/;
  $lines[2]=~s/^Cpus\:([\d\s\.]*)\sus([\d\s\.]*)\ssy([\d\s\.]*)\sni([\d\s\.]*)\sid([\d\s\.]*)\swa([\d\s\.]*)\shi([\d\s\.]*)\ssi([\d\s\.]*)\sst/<td align=center><em>CPU Load<\/em><br>User: $1 &nbsp;&nbsp; System: $2<br>Nice User: $3 &nbsp;&nbsp;Idle: $4<br>IO Wait: $5 &nbsp;&nbsp;Hard Int: $6<br>Soft Int: $7 &nbsp;&nbsp;Steal: $8<\/td><\/tr>/;
  $lines[3]=~s/^KiB\sMem\:([\d\s]*).{4}total([\d\s]*).{4}used([\d\s]*).{4}free([\d\s]*).{4}buffers/<tr><td align=center><em>RAM Usage:<\/em><br>Total: $1 Used: $2<br>Free: $3 Buffers: $4<\/td>/;
  $lines[4]=~s/^KiB\sSwap\:([\d\s]*).{4}total([\d\s]*).{4}used([\d\s]*).{4}free([\d\s]*).{4}cached/<td align=center><em>Swap Usage:<\/em><br>Total: $1 Used: $2<br>Free: $3 Cached: $4<\/td><\/tr>/;
  $top="<tr><th colspan=2>General Info</th></tr>\n".$lines[0]."<tr><th colspan=2>Work Load</th></tr>\n".$lines[1]."\n".$lines[2]."<tr><th colspan=2>Memory Usage</th></tr>".$lines[3]."\n".$lines[4];

  return toTable("System Stats",$top);
}

sub diagnostics{
  my $canSudo=(`sudo -n uptime 2>&1|grep "load"|wc -l`)>1;
  my $hasGpioFile=(-e $scriptFolder.".gpioFile");
  my $serverUser=`whoami`;chomp($serverUser);
  my $tmp=$scriptsPath; $tmp=~s/[\\\/]$//;
  my $permissions= `ls $scriptFolder/.. -l | grep $tmp`; my $fR=""; my $res="";
  if ($permissions=~m/^([d\-])([rwx\-]{3})([rwx\-]{3})([rwx\-]{3})[\s\d]*(\S*)\s*(\S*)/){
	  my $dir=$1;my $owP=$2;my $grP=$3;my $otP=$4;my $ow=$5;my $gr=$6;
	  $res="$dir - $owP - $ow";
	  if ($dir ne "d"){$fR.="Not Directory<br>";};
	  if ($ow ne $serverUser){$fR.="Not owned by $ow<br>";};
	  if ($owP !~/w/){$fR.="$ow can not write<br>";};
	  if ($owP !~/r/){$fR.="$ow can not read<br>";};
  }
  else {
	  $fR="Unable to check $tmp"
  }
  my $vc="";
  if ($hasVc){
	  my $groups=`groups`;
	  if (($groups=~m/\bvideo\b/)&&($groups=~m/\plugdev\b/)){
		  $vc=bar("green","Ok");
		 }
	  else{
		  $vc=bar("red","Unable to use <a onclick=alert('$serverUser needs to belong to groups plugdev and video')>(?)</a>");
	  }
  }
  else {
	  $vc=bar("red","Not installed");
  }
  
  return toTable("piStatus Diagnostics",
      "<tr><th>Web Server User</th><td><b>".$serverUser."</b></td><td>Defines privilige restrictions;</td></tr>".
      "<tr><th>Web Server Groups</th><td><b>".`groups`."</b></td><td>Defines privilige restrictions;</td></tr>".
      "<tr><th>Able to sudo $canSudo</th><th>".($canSudo ?bar("red","Yes"):bar("green","No"))."</th><td>Being able to sudo is a security risk</td></tr>".
      "<tr><th>CGI</th><th>". ($hasCGI ?bar("green","Installed"):bar("red","Not Installed"))."</th><td>Optional recommended</td></tr>".
      "<tr><th>CGI::Carp</th><th>". ($hasCarp ?bar("green","Installed"):bar("red","Not Installed"))."</th><td>Optional (reports errors)</td></tr>".
      "<tr><th>i2c-tools</th><th>". ($hasI2c ?bar("green","Installed"):bar("red","Not Installed"))."</th><td>Needed for I2C control (also check module i2c_bcm2708)</td></tr>".
      "<tr><th>wiringPi</th><th>". ($hasGpio ?bar("green","Installed"):bar("red","Not Installed"))."</th><td>Needed for GPIO</td></tr>".
      "<tr><th>vcgencmd</th><th>$vc</th><td>Optional Core tests</td></tr>".
      "<tr><th>Net Access</th><th>". ($hasWWW ?bar("green","Yes"):bar("red","No"))."</th><td>Optional Connection to WWW</td></tr>".
      "<tr><th>Script Folder</th><td><b>". $scriptFolder."</b></td><td>Folder for storing user scripts and logs</td></tr>".
      "<tr><th>Folder Settings</th><th>". (($fR eq "")?bar("green","OK"):bar("red",$fR))."</th><td>Check folder ok for use</td></tr>".
      "<tr><th>.gpioFile</th><th>".($hasGpioFile ?bar("green","Yes"):bar("red","No"))."</th><td>Stores GPIO states, created after submission</td></tr>".
      "<tr><th>piGears</th><th>". ($hasGears ?bar("green","Yes"):bar("red","No"))."</th><td>The interpreter for piGears scripts</td></tr>");
	
	sub bar{
		return "<div class=".shift."bar>".shift."</div>";
	}
}

sub memStats{
  my $memStatus=`df -m | grep rootfs`."\n".`free -m |grep Mem`; 
  my $barChart="";
  $memStatus=~s/rootfs\s+(\d+)\s+(\d+)\s+(\d+).+\n/<tr><th rowspan=2>SD Card(MB)<\/th><td> Total $1, Used $2, Free $3<\/td><\/tr>/;
  if ($1!=0){
	   my $SDused=int(20*$2/$1)."em";my $Pused=int(100*$2/$1);
	   my $SDfree=int(20*$3/$1)."em";my $Pfree=int(100*$3/$1);
	   my $swap=20-$SDused-$SDfree;
	   $barChart="<tr><td><div class=barContainer><div class=barUsed style='width:$SDused;'>$Pused %</div><div class=barFree style='width:$SDfree;'>$Pfree %</div><div class=barRest style='width:$swap;'>s</div></div></td></tr>";
   }
  $memStatus=~s/Mem:\s+(\d+)\s+(\d+)\s+(\d+).+/$barChart<tr><th rowspan=2>Pi RAM (MB)<\/th><td> Total $1, Used $2, Free $3<\/td><\/tr>/;
  if ($1!=0){
	  my $SDused=int(20*$2/$1)."em";my $Pused=int(100*$2/$1);
	  my $SDfree=int(20*$3/$1)."em";my $Pfree=int(100*$3/$1);
	  $barChart="<tr><td><div class=barContainer><div class=barUsed style='width:$SDused'>$Pused %</div><div class=barFree style='width:$SDfree'>$Pfree %</div></div></td></tr>";
  }
  return toTable ("Memory Status", $memStatus.$barChart);
}

sub about{
		 @uname=split(" ",`uname -a`);
		 $uname[4].="<br>";
		 $uname[10].="<br>";
		 $return = toTable("piStatus has loaded successfully",
		           "<center>".join(" ",@uname)."<br><br>".
		           "<a href=http://www.windon.themoon.co.uk/NVSM/WebControl target=_new>piStatus</a> Version $version <br>".
		           ($hasGears?("<a href=http://www.windon.themoon.co.uk/NVSM/piGears target=_new>piGears</a> Version ".`piGears.pl v`."<br>"):"").
		           "Copyleft Under GPL 2.0+<br>Saif Ahmed<br>") ;	
}


sub hardware{
	my @cpuStatus=`cat /proc/cpuinfo`; 
	my $tr="";
	foreach $line (@cpuStatus){
		if ($line=~m/^([^:]*):(.*)$/){
			my $par=$1; my $val=$2;
			$tr.="<tr><td>$par</td><td>$val</td></tr>";
		}
	}
	$tr.="<tr><td>Model</td><td>$Board</td></tr>";
	return toTable("CPU Information",$tr);
}

sub modules{

  my @lsRows=`lsmod`;
  shift(@lsRows);
  foreach (@lsRows){
        $_=~s/^([^\s]*)[^\d]*(\d*)[^\d*](\d*)\s(.*)$/<tr><td>$1<\/td><td>$2<\/td><td>$3<\/td><td>$4<\/td><\/tr>/;
    }
  my $lsmod="<tr><th>Name</th><th>Size</th><th></th><th>Used By</th></tr>".join("\n",@lsRows);
    return toTable("Modules" ,$lsmod);
}
sub env{
  my @lsRows=`printenv`;
  foreach (@lsRows){
        $_=~s/^([^=]*)=/<span class=bold>$1<\/span>=/;
    }
  return toTable("Environment Variables" ,"<div class=smaller>".join("<br>\n",@lsRows)."</div>");
}

sub taskMan{
	my @top=  `top -b -n 1`;
	my @lines=`pstree -p -u -U`;
	my @top=  `top -b -n 1`;
	my $user=`whoami`;chomp($user);
	@top=@top[8..scalar(@top)];
	my %pidHash=();
	foreach my $line (@top){
		chomp($line);
		$line=~s/\s*(\d+)\s+(\S+)\s+\S+\s+\S+\s+\S+\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(\S+)\s+(.+)/PID:$1 USER:$2 \%CPU:$6 \%MEM:$7 TIME:$8  COMMAND:$9/;
		#can only kill when user is owner of the process, and prevent killing of server.
		my $pid=$1;
		if(($2 eq $user) && ($9 !~/lightppd|httpd|apache2|nginx|hiawatha/) ){
			$line.=" <span class=bold> ..Click PID to Kill</span>\")' onclick='piStatus(\"stats\",\"k\",\"$pid";
			};
		$pidHash{$pid}=$line;
	}
	my $temp="";
	my $next=0;
	foreach my $line (@lines){
		my $lineNow=$line;
		$lineNow=~s/{[^}]*}(\([\d]*\))//;
		my $dummy=$1;
		if ($lineNow=~m/[a-z]/) {
			if($next) {$next=0;$temp.="\n";}
			 $temp.=$line;}
		else {chomp $temp; $temp.=$dummy; $next=1}
		$dummy=~s/[\(\)]//g;
		if (!$pidHash{$dummy}){$pidHash{$dummy}="No process information";}
		
	}
	$temp=~s/\n/<br>/g;
	$temp=~s/\s/&nbsp;/g;
	$temp=~s/\((\d+)([\)\,])/(<a class=pid onmouseout='divText(\"psStatus\",\".. Put pointer on PID to get process info\")' onmouseover='divText(\"psStatus\",\"..$pidHash{$1}\")' >$1<\/a>$2/g;
	
	return  toTable("Process Tree" ,"<div class=psStatus id=psStatus>.. Put pointer on PID to get process info</div><div style='font-family:monospace,courier;font-size:0.8em'>$temp</div>");

}

sub usb{

  my @lsRows=`lsusb`;
  foreach (@lsRows){
        $_=~s/.{3}(.{5}).{6}(.{4}).{5}(.{9})(.*)$/<tr><td>$1<\/td><td>$2<\/td><td>$3<\/td><td>$4<\/td><\/tr>/;
    }
  $lsusb="<tr><th>Bus</th><th>Device</th><th>ID</th><th>Information</th></tr>".join("\n",@lsRows);
    return toTable("USB Devices" ,$lsusb);
}

sub vcgencmd{
	if ($hasVc){
		my $clocks="<b>CLOCKS</b><br>";
		my @clockList=qw(arm core h264 isp v3d uart pwm emmc pixel vec hdmi dpi);
		foreach(@clockList){
			my $freq=`/opt/vc/bin/vcgencmd measure_clock $_`;
			$freq=~s/frequency\(\d+\)=//;
			$freq=~s/000$/kHz/;$freq=~s/(\d)00kHz$/.$1MHz/;
			$clocks.=$_.":".$freq."<br>";
		}
		my $codecs="<b>CODECS</b><br>";
		my @codecList=qw(H264 WVC1 MPG2);
		foreach(@codecList){
			$codecs.=`/opt/vc/bin/vcgencmd codec_enabled $_`."<br>";
		}
		my $voltages="<b>Voltages</b><br>";
		my @voltList=qw(core sdram_c sdram_i sdram_p);
		foreach(@voltList){
			my $volts=`/opt/vc/bin/vcgencmd measure_volts $_`;
			$volts=~s/volt/ /;
			$voltages.=$_.$volts."<br>";
		}
		
		my $temp=`/opt/vc/bin/vcgencmd measure_temp`;
		$temp=~s/temp=/<b>Temperature<\/b><br>/;
		$temp=~s/\'/&deg;/;
		
		my $version="<b>Version</b><br>".`/opt/vc/bin/vcgencmd version`;
		$version=~s/\n/<br>/g;
		
		my $table="<tr><td>$version<br>$codecs<br><br>$voltages</td><td>$temp<br><br>$clocks</td></tr>";
		
		return toTable("Volts,Temp,Clocks,Codecs",$table);
	}
	else {
		return toTable("Temp,Clocks,Codecs",
		   "This tool requires vcgencmd.  This has not been found<br>".
		   "Please update your system, (e.g. using rpi-update)");
	}
	
}

#### Logging
sub sio{
	return toTable("piStashIO","A method for inter-pi communication of IO states and<br>other messages: piStashIO is not installed");
		
}

sub saveLogs{
	my ($logFile,$newData)=@_;
	my $oldFile="";
	if (-e $scriptFolder.$logFile){
		$oldFile=loadFile($logFile);
		saveFile($logFile.".tmp",$oldFile);
	}
   	my $newFile=$newData."\n".$oldFile;
   	saveFile($logFile,$newFile);
}

sub lastLogEntry{ #gets first line
	my $logFile=shift;
	my $lastEntry="";
	if (-e $scriptFolder.$logFile){
		open (FOO,  $scriptFolder.$logFile) ||   return toTable("File Error","ERROR Unable to open  $scriptFolder.$logFile: $!\n");
		$lastEntry = <FOO>;
		close FOO;
	}
	chomp $lastEntry;
	return $lastEntry;
	
}

sub lastIPs{
	my $count=shift;
	my $row="";
	my $IPlog=".IPLog";
	if (-e $scriptFolder.$IPlog){
		open (FILE,"<$scriptFolder$IPlog") || return toTable("File Error","Error Can't load  $scriptFolder$IPlog  $!");
		while (<FILE>){
			$count--;
			if (($count < 0) || ($_ !~/$visitorIP/)){
				$row.=$_;
				};
		}
		close FILE;
	};
	saveFile($IPlog,localtime(time())." - ".$visitorIP."\n".$row);
}

sub toTable{
	my ($title,$content)=@_;
	return "<table class=status border=1><tr><th  valign=middle>$title</th></tr><tr><td><table class=statusContent><tr><td>$content</td></tr></table></td></tr></table>"
}

sub rawToView{
	my $raw=shift;
	$raw=~s/</&lt;/g;
	$raw=~s/\n/<br>/g;
	if (shift) {$raw=~s/ /&nbsp;/g;}
	return $raw;
}

sub setStyles{

if (-e $scriptFolder."piStatus.css") {
	 $styleLine='<link rel="Stylesheet" type="text/css" href="'.$scriptFolderURL.'piStatus.css" />';
  }
else {
	  $styleLine = <<ENDSTYLE;
<style>
body{color:darkblue;font-family:sans,arial;}
th{color:red;text-valign: middle;}
.btn{color:green;padding-right:4px;padding-left:4px;background-color:azure;border:outset;display:block;}
.btn:hover{color:red;background-color:lightblue;border:inset;color:red}
.unBtn{padding-right:4px;padding-left:4px;background-color:azure;border:inset;display:block;}
.left{float:left}
.right{float:right}
.piMenu{float:left;font-size:0.8em}
table.gTable{font-size:0.75em;font-family:sans;}
td.pin{width:1.5em;border-style:solid;border-width:.5em;text-align:center;font-weight:bolder;}
td.on{background-color:green}
td.off{background-color:red}
td.power{background-color:cyan}
td.ground{background-color:black}
td.undefined{background-color:orange}
td.label{font-size:1.5em;}
div.main{clear:both;font-family:sans,arial}
table.stMenu{}
table.chart{border-collapse:collapse}
th.time{width:3px;}
div.stMenu{font-size:0.8em;width:7em;text-align:center}
div.barContainer{width:20.5em;height:1.5em;}
div.barUsed{text-align:center;background-color:pink;float:left;border:3px solid;border-color:cyan;display:block}
div.barFree{text-align:center;background-color:lightgreen;float:left;border:3px solid;border-color:cyan;display:block}
div.barRest{text-align:center;background-color:yellow;float:left;border:3px solid;border-color:cyan;display:block}
div.greenbar{text-align:center;background-color:darkgreen;color:white;font-weight:bolder;border:3px solid;border-color:cyan;display:block}
div.redbar{text-align:center;background-color:darkred;color:white;font-weight:bolder;border:3px solid;border-color:cyan;display:block}
table.status{font-size:0.8em;box-shadow: 10px 10px 5px #888888;}
a.pid{color:red}
a.pid:hover{color:green}
span.bold{color:magenta;font-weight:bolder}
div.fileList{width:35em;clear:both}
div.file{float:left}
div.folder{float:left;font-weight:bolder}
div.smaller{font-size:0.8em}
div.psStatus{font-size:0.8em;color:green;width:40em;height:2.5em;}
div.shell{font-family:monospace;color:white;background-color:black;height:20em;width:40em;overflow:auto;}
div.shellHistory{font-family:monospace;color:green;background-color:lightyellow;height:3em;width:38em;overflow:auto}
</style>
  
ENDSTYLE

}	


if (-e $scriptFolder."piGears.css") {
	 $gearsStyleLine='<link rel="Stylesheet" type="text/css" href="'.$scriptFolderURL.'piGears.css" />';
  }
else {
	  $gearsStyleLine = <<ENDSTYLE;
<style>
span.ln{}
span.command{color:magenta}
span.rest{color:green}
span.com{color:red}
div.absolute{position:absolute;}
</style>
ENDSTYLE

}	


}


print <<END_HTML;
Content-Type: text/html; charset=UTF-8

<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<title>piStatus - Raspberry Pi Web Control</title>
<head>
<script>
$gpioJS
gpioMods=new Array();
piStatusScript="$piStatusScript";

NS4 = (document.layers) ? 1 : 0;
IE4 = (document.all) ? 1 : 0;
W3C = (document.getElementById)  ? 1 : 0;

function newFile(dir,fd){
	var fName=document.getElementById("newFile").value;
	fd= fd?"Directory":"File";
	if (fName!=""){
		if (validFileName(fName,dir)) { if (confirm("Create New " + fd +" - "+((dir!="")?(dir+"/"):"")+fName)) piStatus("new",dir+"/"+fName,fd);}
		else alert ("Invalid "+fd + " Name Specified");
    }
	else alert ("No File Name Specified");
}

function upload(){
	var fName=document.getElementById("uploadFile").value;
	if (fName!=""){
	  if (confirm("Upload File - "+fName)) document.getElementById("uploadForm").submit();
    }
	else alert ("No File Specified");
	
}


function rename(fName){
	var newName=prompt ("Enter New Name for File " + fName,fName);
	if (!newName) return;
	if (validFileName(newName)){
		piStatus("ren",fName,newName)
	}
	else alert("Invalid FileName");
}


function validFileName(name,dir){
	
	var validFile=/^[a-z0-9-_\/]+\\.?[a-z0-9]{0,3}\$/i;
	return validFile.test(name);
}

function formPoster(dvPairs){
	var fm=document.getElementById("form");
	if (!fm){
		fm=document.createElement("form");
		document.body.appendChild(fm);
	}
	fm.action=piStatusScript;
	for (var x=0;x<dvPairs.length;x+=2){
		fm.appendChild(makeInpElement(dvPairs[x],dvPairs[x+1]));
	}
	if ($debug) fm.appendChild(makeInpElement("debug","on"));
$formMethods
	fm.submit();
}

function makeInpElement(name,value){ 
	    var e=document.createElement("input");
	    if (value=="getFromUI"){
			e.type=document.getElementById(name).type;
			value=document.getElementById(name).value;
		}
		else {
			e.type="hidden";
		}
		e.name=name;
		e.value=""+value;
	return e;
}

function setValues(pin,element,mode){
	var extras=new Array("",",in,out,pwm",",tri,up,down",",1,0")
	if (document.getElementById("selector")){
		var temp=document.getElementById("selector").value;
		document.getElementById("selector").parentNode.onclick=function(){
			 setValues(pin,this,mode)
		 }
		document.getElementById("selector").parentNode.innerHTML=temp;
	}
	var options =(element.innerHTML+extras[mode]).split(",");
	selector=document.createElement("select");
	selector.id="selector";
	for (var oc=0;oc<options.length;oc++){
		var oe=document.createElement("option");
		oe.appendChild(document.createTextNode(options[oc]));
		oe.value=options[oc];
		selector.appendChild(oe);	
	}
	
	//selector.innerHTML="<option>"+options.join("<option>");
	selector.onchange=function(){
		 var pn=selector.parentNode;
		 var val=selector.value;
		 pn.removeChild(selector);
		 pn.appendChild(document.createTextNode(val));
		 gpioSet(pin,this.value,mode);
		 pn.onclick=function(){
			 setValues(pin,element,mode)
		 }
	 }
	
	element.innerHTML=("");
	element.appendChild(selector);
	element.onclick=null;
}

function  gpioSet(pin,value,mode){
	var found=0;var index=0;
	while ((!found)&&(index<gpioArray.length)){
		var tp=gpioMods[index]?gpioMods[index].split(":"):gpioArray[index].split(":");
		if(tp[0]==pin) {
			tp[mode]=value;
			found=true;
			gpioMods[index]=tp.join(":")
		}
		index++
	}
}

function popOut(parameters) {
	newwindow=window.open(piStatusScript+"?"+parameters,'piStatusPopOut','height=370,width=150');
	if (window.focus) {newwindow.focus()}
	return false;
}


function piStatus(command,file,data){
	formPoster(new Array("command",command,"file",file,"data",data));
}

function hoverText(object,text){
	while (object.firstChild) {object.removeChild(object.firstChild)}
	if (text != ""){
		var sp=document.createElement("span");
		var xy=findPos(object)
		sp.style.position="absolute";
		sp.style.top=xy[1]+"px";
		sp.style.left=xy[0]+"px";
		sp.appendChild(document.createTextNode(text));
		object.appendChild(sp);
	}
}

function divText(divId,text){
	document.getElementById(divId).innerHTML=text;
}


// http://www.quirksmode.org/js/findpos.html
function findPos(obj) {
	var curleft = curtop = 0;
	if (obj.offsetParent) {
		do {
			curleft += obj.offsetLeft;
			curtop += obj.offsetTop;
			} while (obj = obj.offsetParent);
		}
	var ar=new Array(curleft,curtop)
	return ar;
}

</script>
$styleLine
$gearsStyleLine
</head>
<body>
<div  class=piMenu>
<a class="btn left" onclick=piStatus('stats')>System</a>
<a class="btn left" onclick=piStatus('gpio')>GPIO</a>
<a class="btn left" onclick=piStatus('i2c')>I2C</a>
<a class="btn left" onclick=piStatus('sio')>StashIO</a>
<a class="btn left" onclick=piStatus('list')>File Manager</a>
<a class="btn left" onclick=piStatus('shell')>Shell</a>
</div>
<br>
<div class="main">$status</div>
<div class=debug>$debugScript</div>
</body>
</html>
END_HTML


