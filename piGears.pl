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
#       FileName: piGears.pl

#check installed modules
  eval "use CGI"; $hasCGI = $@ ? 0 : 1;
  eval "use CGI::Carp"; $hasCarp = $@ ? 0 : 1;
  if ($hasCarp)   {use CGI::Carp qw(fatalsToBrowser);}
  $hasGpio=(`which gpio`=~m/gpio/)? 1:0;
  $hasVc=(`which /opt/vc/bin/vcgencmd`=~m/vcgencmd/)? 1:0;
  
 $scriptsPath="scripts/";     # IMPORTANT Change this to the path of
                              # scripts from document root.
                              # This folder needs to be writeable by www-data or
                              # whatever the web server userID is .
 
 #######################Nothing below this needs to be changed#############################
 ###########################################################################################

 $version = "0.7";

 $reqURI = $ENV{'REQUEST_URI'};
 $host = $ENV{'HTTP_HOST'};
 $docRoot = $ENV{'DOCUMENT_ROOT'};
 $visitorIP = $ENV{'REMOTE_ADDR'}; ##REMOTE_HOST in some systems;
 $scriptFolder=$docRoot."/".$scriptsPath;$scriptFolder=~s/\/\//\//;
 $scriptFolderURL="http://".$host."/".$scriptsPath;   
 $Parameters=$reqURI?$reqURI:join("",@ARGV);
 $Parameters=~s/^([^\?]*)\?//;
 $piGearsScript=$1?$1:$reqURI;
 $piStatusScript=$piGearsScript;
 $piStatusScript=~s/piGears/piStatus/;
 $timeStamp=time();
 $ReadableTime = localtime($timeStamp);

# make a scripts folder if not already available
    if (! -e $scriptFolder ){
		$hasDir= mkdir $scriptFolder  ;
		if(!$hasDir){$hasDir.=$!};
	}
	else {$hasDir="Yes"}


$argLength=@ARGV;
if ($argLength>0){
	$command=$ARGV[0];
	$file=$ARGV[1];
	$data=$ARGV[2];
	if ($command eq "v") {print $version."\n";exit 1;};
	
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
}


#detect board revision
    $RevCode=`cat /proc/cpuinfo | grep Revision`;
    $RevCode=~s/[^0-9]//g;
    if ($RevCode  eq "0002") {$Board="Model B Revision 1.0"} 
    elsif ($RevCode  eq "0003") {$Board="Model B Revision 1.0 + ECN0001 (no fuses, D14 removed)"}
    else {$Board="Model B Revision 2.0"};
    
if ($RevCode=~m/0002|0003/){
	@gpioPins=(0, 1, 4, 7, 8, 9, 10, 11, 14, 15, 17, 18, 21, 22, 23, 24, 25);
	@pinDefs=("3V3","5V0","00G","DNC","01G","GND","04G","14G","DNC","15G","17G","18G","21G","DNC","22G","23G","DNC","24G","10G","DNC","09G","25G","11G","08G","DNC","07G");
}
else {
	@gpioPins=(2, 3, 4, 7, 8, 9, 10, 11, 14, 15, 17, 18,  22, 23, 24, 25, 27);
	@pinDefs=("3V3","5V0","02G","DNC","03G","GND","04G","14G","DNC","15G","17G","18G","27G","DNC","22G","23G","DNC","24G","10G","DNC","09G","25G","11G","08G","DNC","07G");
}
	@gpioData=split("\n",loadFile(".gpioFile"));


@statements=();
@pCStack=();
@dataStack=();
$end=0;
%gV=();$gV{"ORIGINX"}=0;$gV{"ORIGINY"}=100;$gV{"SCALEX"}=1;$gV{"SCALEY"}=1;
%labels=();
$logs="";
$errors="";
$Console="";
$Listing="";
$prStyle="";
$logging=1;
$limit=3000;
$showMenu=1;
$fio=0;
$fioBuffer="";
$status="";
if ($command eq ""){
		$status=about();
}
elsif ($command eq "run"){
		unlink $scriptFolder.$file.".log"  || logLine("cannot delete logfile $scriptFolder$file.log ");
		my $script=load();
		if(!$script){
			$status=toTable("Failed to load $file","");
		}
		elsif ($file=~m/\.pgl$/i){
			clean($script);
			if ($logs =~m/\nERROR:/) {
				$Console.="Error Found...view logs\n";
		    }
		    else{
				$end=@statements;
				run(0);
			}
		}
		elsif ($file=~m/\.scr$/i) {
			@statements=split("\n",$script);
			for (my $count=0;$count <@statements;$count++){$Listing.=lineParse($count,"list");}
			$end=@statements;
			run(0);
		};
		
		
		$status=progView();
}	

sub run{
    $pC=shift;
    my $c=0;
    #include things
    while($c<@statements){
		my $tmp=$statements[$c];
		$tmp=~s/^<b(\-?\d+)>\s*//;
		my $currInd=$1;
		if ($tmp=~m/^\s*include\s+([a-z0-9]*)$/i){
			my $inPt=0;
			@loadedScr=split("\n",loadFile("lib/".$1.".scr"));
			logLine("\n...Merging "."lib/".$1.".scr\n"."\n...".@loadedScr." lines found");
			if (@loadedScr[0] =~m/library/){ shift(@loadedScr) };
			foreach (@loadedScr){
				splice @statements,$inPt+$c,($inPt?0:1),addIndent($_,$currInd);
				$inPt++;
			}
		}
		$c++;
		$end=@statements;
	}
	#$Listing="";for (my $count=0;$count <@statements;$count++){$Listing.=lineParse($count,"list");}
    
    #labels and subroutines:
    $c=0;
    foreach (@statements){
		my $tmp=$_;
		$tmp=~s/^<b(\-?\d+)>\s*//;
		if ($tmp=~m/^\s*(label|sub)\s+([a-z0-9]*)(\s.*)?$/i){
			$labels{"\U$1".$2}=$c;
			logLine("\n...\U$1 ".$2." is at ". $labels{"\U$1".$2});
		}
		$c++;
	}

    #Main interpreter loop
	while (($pC!=-1)&&($pC<@statements)&&($limit>0)){
		$pC=lineParse($pC,"run");
		if ($pC =~m/Error/){
			logLine($pC."\n");
			$pC=-1;
		}			
		$limit--;
		if ($limit==0) {logLine("\n...limit on execution statements reached")};
	}
	$logging=1;
	logLine("\nExecution finished on ".localtime(time()));

	sub addIndent{
		my($line,$add)=@_;
		$line=~s/^<b(\-?\d+)>\s*//;
		$line="<b".($add+$1).">".$line;
		return $line;		
	}
	
}

sub evaluate{
	my $expression=shift;
	my $preval="";
	while ($expression ne ""){
		my $buffer=$expression;
		if ($expression=~m/([a-z][a-z0-9]*)\(([^\(\)]*)\)/i){
			my $res=SUBROUTINE($1,$2);
			$expression=~s/([a-z][a-z0-9]*)\(([^\(\)]*)\)/$res/i;
			}
		elsif ($expression=~m/^\s*(\"[^\"]*\")/i){ $preval.=$1;logLine("\n...found a string $1");$expression=~s/^\s*(\"[^\"]*\")//i}
		elsif ($expression=~m/^\s*([\+\-\(\)\*\/<>=\.\[\],])/){$preval.=$1;logLine("\n...found a $1"); $expression=~s/^\s*([\+\-\(\)\*\/<>=\.\[\],])//i; }
		elsif ($expression=~m/^\s*(eq|ne|lt|gt)(\s.*)+/){$preval.=" ".$1." ";logLine("\n...found a $1"); $expression=~s/^\s*$1//i; }
		elsif ($expression=~m/^\s*([a-z][a-z0-9]*)[^\(\[a-z0-9]/i){logLine("\n...found a $1");  $preval.="\$gV{".$1."}";$expression=~s/^\s*$1//}
		elsif ($expression=~m/^\s*([a-z][a-z0-9]*)\[(.+)\]/i){logLine("\n...found a $1 [ $2 ]");  $preval.="\$gV{".$1."}[".evaluate($2)."]";$expression=~s/^\s*$1\[([\d+])\]//}		
		elsif ($expression=~m/^\s*(\d+)/){$preval.=$1;logLine("\n...found a $1"); $expression=~s/^\s*$1//;}	
		elsif ($expression=~m/\s*([a-z][a-z0-9]*)$/i){logLine("\n...found a $1");  $preval.="\$gV{".$1."}";$expression=~s/\s*$1$//}
		if ($buffer eq $expression) {$expression="";logLine("\n...END Eval at $preval..$buffer ")}
	}
	
	if  ( eval($preval) =~m/ARRAY\(/) {
		logLine("\n...Evaluating an array ");
		return "Array (".join(",",@{eval($preval)}).")";
	}
	else {
		logLine("\n...Evaluating ".$preval );
		return eval($preval);
	}
}



sub clean{  # eliminate line numbers
	my $program=shift;
	$program=~s/\s*([\{\}])\s*/\n$1\n/g;
	$program=~s/([^\\])\;/$1\n/g;  #un escaped semicolons counts as statement separator
	$program=~s/\n+/\n/g;  # remove empty lines
	chomp($program); 
	@statements=split (/\n/,$program);
	$end=@statements;
	$Listing="";
	my $bracLevel=0;
	for (my $lineCount=0;$lineCount<$end;$lineCount++){
		$statements[$lineCount]=~s/^\s+//;$statements[$lineCount]=~s/\s+$//; #Trim beginning and end
		if ($statements[$lineCount] =~m/\}/){$bracLevel--;};
		setBracLevel($lineCount,$bracLevel);
		if ($statements[$lineCount] =~m/\{/){$bracLevel++;};
		if ($bracLevel < 0) {
			logLine("\nERROR: Closing } without matched opening { at statement $lineCount");
			$statements[$lineCount].="   #!ERROR";
			$bracLevel=0;};
	}
	if ($bracLevel>0){ logLine("\nERROR: Unclosed { ($bracLevel found)")};
	for (my $lineCount=0;$lineCount<$end;$lineCount++){
		if (lineParse($lineCount)=~m/^(times|if|else|elseif|while|for|sub)$/i){
			if (lineParse(1+$lineCount) !~/\{/){
				indent(1+$lineCount);
			}
			else {
				for (my $iC=1+$lineCount;$iC<nextClose(1+$lineCount)+1;$iC++){
					if ($iC<$end) {indent($iC)}
					}
			}
		}
		$Listing.=lineParse($lineCount,"list")
	}
	my $cleaned=join("\n", @statements);
	$cleaned=~s/\n+/\n/g;$cleaned=~s/^\n//;
	@statements=split("\n",$cleaned);
	my $scr=$file;
	$scr=~s/pgl$/scr/i;
	if ($statements[0] =~m/library/){
		 if ($scr=~m/\//) {$scr=~s/^.*(\/[^\/]+)$/lib$1/}
		 else {$scr="lib/$scr"}
	}
	saveFile($scr,$cleaned);
	logLine("\n Number of statements found = $end ");

sub indent{
	my $line=shift;
	setBracLevel($line,1+getBracLevel($line));
}

sub setBracLevel{
	my ($line,$level)=@_;
	$statements[$line]=~s/^<b\d*>//;
	$statements[$line]="<b".$level.">".$statements[$line];
}

}

sub command{
	return lineParse(shift);
}

sub getBracLevel{
	return 1*lineParse(shift,"brac");
}

sub lineParse{
	my ($lN,$mode)=@_;
	my $statement=$statements[$lN];
	$statement=~s/^<b(\-?\d+)>//;
	my $bracLevel=$1;
	if ($mode eq "brac") {return $bracLevel};
	my $head="<span class=ln>". ("0" x (4-length($lN))).$lN."</span>".("&nbsp;&nbsp;&nbsp;" x  (1+$bracLevel));
	$statement=~s/(#.*)?$//;
	my $comment=$1;
	
	my $body="";
	if ($mode eq "run"){logLine("\nExecuting line $lN")};
	
	if ($statement =~m/^\s*(\S.*)\sTIMES\s*(#.*)*$/i){
		my $rest=$1;
		if ($mode eq "run"){
			TIMES($rest);$lN++;
		}
		elsif ($mode eq "list"){
			$body="<span class=rest>$rest</span> <span class=command>TIMES</span>";		
		}
		else {return "TIMES";}
    }
    elsif ($statement =~m/^\s*([a-z][a-z0-9]*)(\[[^=]*\])?\s*\=\s*(\S.*)$/i){
		if ($mode eq "run"){
			LET("$1$2=$3");
		}
		elsif ($mode eq "list"){
			$body="<span class=command>LET</span> <span class=rest>$1$2</span>=<span class=rest>$3</span>";			
		}
	    else {return "LET";}
    }
	elsif ($statement =~m/^\s*([a-z]+)(\s+(\S.*))?/i){
	   my $command=$1; my $rest=$3;$command=~tr/a-z/A-Z/;
	   if (($command =~m/^ELSE$/i)&& ($rest =~m/^if/i)){
		   $command = "ELSEIF"; $rest =~s/^if//;
	   }
	   if ($mode eq "run"){
		  logLine(" $command $rest");
		  $rest=~s/\"/\\\"/g;
	      eval ("$command(\"$rest\")");
	      logLine( $@?" Failed $command ($rest) $!":"");
	      $lN=$pC;			
		}
		elsif ($mode eq "list"){
			$body="<span class=command>$command</span> <span class=rest>$rest</span>";			
		}
		else{return $command}
    }
    elsif ($statement=~m/^\s*([\{\}])/){
		my $command=$1;
		if ($mode eq "run"){
			$command=($command =~m/\{/)?"OPENBRACKET":"CLOSEBRACKET";
			logLine($command) ;
			$lN=eval ("$command($lN)");
			logLine (" ...should go to $lN +1");
			logLine( $@?" Failed $command":"");
		}
		elsif ($mode eq "list"){
			$body="<span class=command>$command</span>"			
		}
	    else{return $command;}
	}
    else {
		if ($mode eq "run"){
			 logLine(" Line $lineNumber Ignored ($statement)");			
		}
		elsif ($mode eq "list"){
			$comment="#".$statement.$comment;			
		}
	    else{return "REM";}
	}
	
	if ($mode eq "run") { return ++$lN };
	return $head.$body."<span class=comment>".$comment. " </span>"."<br>";
}

sub SET{
   my $rest=shift;
   if ($rest=~m/\s([^\,]+)\,([^\,]+)/){
	   my $pin=evaluate($1);my $mode=$2;
	   if (validPin($pin)){
		   if  ($mode=~m/in|out|pwm/){
			   GPIO("$pin:$mode::\n");
			   logLine("\n...Setting Pin $pin to Mode $mode");
			   }
	       elsif ($mode=~m/up|down|tri/){
			   GPIO("$pin::$mode:\n");
			   logLine("\n...Setting Pin $pin to Mode $mode");
			   }
		   else{
			   logLine("\n...ERROR invalid Mode $mode");
		   }
	   }
	   else {
		   logLine("\n...ERROR invalid Pin $pin");
	   }
   }
}

sub OUT{
   my $rest=shift;
   if ($rest=~m/([^\,]+)\,([^\,]+)/){
	   my $pin=evaluate($1);
	   if (validPin($pin)){
		   my $output=evaluate($2);
		   logLine("\n...Setting Pin $pin output to $output");
		   GPIO($pin.":out::".$output."\n");
	   }
	   else{
		   logLine("\n...ERROR invalid Pin $pin");
	   }
   }
   else {logLine("\n...failed output $rest")};
}

sub OUTM{
	my $rest=shift;my $GPString="";
	if ($rest=~m/([a-z0-9]+)[\s\,]*b([10]+)\s?$/){
		my @pinArr=@{$gV{$1}};my @pinData=split(//,$2);my $c=0;
		logLine("\n...binary OutM ".join(",",@pinData));
		foreach my $pin (@pinArr){
			if (validPin($pin)){
				$GPString.="$pin:out::".$pinData[$c]."-";
				logLine("..setting it to ".$pinData[$c]);
				$c++;
			}
		}
		GPIO($GPString);
	}
	elsif ($rest=~m/([a-z0-9]+)[\s\,]*([\d]+)/){
		my $arrName=$1;my $out = unpack("B*", pack("N", $2));
		my $arrLength=@{$gV{$arrName}};
		$out =~s/^.*([\d]{$arrLength})/$1/;
		logLine("\n...Decimal OutM  $out");
		OUTM("$arrName,b$out");
	}
	else {logLine("\n...failed multiple output $rest")};

}

sub IN{
	my $pin=evaluate(shift);
	my $pinPos=validPin($pin);
	if ($pinPos){
		$pinPos--;
		logLine("\n...Reading Pin $pin");
		return (split(//,GPIO($pin.":in::\n")))[$pinPos];
		
	}
   	else{
		   logLine("\n...ERROR invalid Pin $pin");
	}
}

sub INM{
	my @pinArr=@_;my $no=@pinArr;
	my @pinStates=split(//,GPIO());
	my $result="";
	if (($no==1)&&($pinArr[0]=~m/([a-z][a-z0-9]+)/)){
		@pinArr=@{$gV{$pinArr[0]}};
	}
	my $c=0;
	logLine("\n...Multi Read ... ".join(",",@pinArr));
	foreach my $pin (@pinArr){
		my $pinPos=validPin($pin);
		if ($pinPos){
			$pinPos--;
			$result.=@pinStates[$pinPos];
			logLine("\n...Reading Pin $pin = ".@pinStates[$pinPos]);
		}
	}
	return "\"b".$result."\"";
}


sub EXPORTIO{
	my $tmp=shift;
	my ($mode,@pins)=split(/[,\s]/,$tmp);
	if ((@pins == 1)&&($pins[0]=~m/\s*([a-z][a-z0-9]*)\s*$/)){
			@pins=@{$gV{$1}};
			foreach (@pins){
				logLine("\n...Exporting  $_ $mode ");
				`/usr/local/bin/gpio export $_ $mode 2>&1`;
			}
	}
	else {
		    foreach (@pins){
			my $pin=evaluate($_);
			logLine("\n...Exporting 2  $pin $mode ");
			`/usr/local/bin/gpio export $pin $mode 2>&1`;
		}
	}
	SHELL("/usr/local/bin/gpio exports");
}

sub FASTOUTM{
	my $rest=shift;my $GPString="";
	if ($rest=~m/([a-z0-9]+)[\s\,]*b([10]+)\s?$/){
		my @pinArr=@{$gV{$1}};my @pinData=split(//,$2);my $c=0;
		#logLine("\n...binary FastOutM ".join(",",@pinData));
		foreach my $pin (@pinArr){
			if (validPin($pin)){
				open (GPIOPIN,">/sys/class/gpio/gpio$pin/value") || logLine("\n...failed to open /sys/class/gpio/gpio$_/value : $!");
				unless (print GPIOPIN $pinData[$c])
				   {logLine("\n...failed to print to  /sys/class/gpio/gpio$pin/value : $!");}
				close GPIOPIN;
				#logLine("\n...Setting $pin to ".$pinData[$c]);
				$c++;
			}
		}
	}
	elsif ($rest=~m/([a-z0-9]+)[\s\,]*([\d]+)/){
		my $arrName=$1;my $out = unpack("B*", pack("N", $2));
		my $arrLength=@{$gV{$arrName}};
		$out =~s/^.*([\d]{$arrLength})/$1/;
		#logLine("\n...Decimal OutM  $out");
		FASTOUTM("$arrName,b$out");
	}
	else {logLine("\n...failed multiple output $rest")};
}

sub SUBROUTINE{
	my ($command,$parameters)=@_;
	logLine("\n...Evaluating func $command on $parameters");
	if ($command =~m/^inm?|pop$/i){
		return eval ("\U$command(".$parameters.")");
	}
	elsif ($command =~m/^(sin|cos|tan|log|atan|acos|asin|rand|int|ceil|floor|sqrt)?$/i){
		$command= lc $command;
		return eval("$command(".evaluate($parameters).")");
	}
	elsif ($command =~m/^(substring|left|right|mid|isEmpty|len)?$/i){
		$command= lc $command;
		return eval("$command($parameters)");
	}
	else {return ""};

sub asin { atan2($_[0], sqrt(1 - $_[0] * $_[0])) }
sub acos { atan2( sqrt(1 - $_[0] * $_[0]), $_[0] ) }
sub tan  { sin($_[0]) / cos($_[0])  }
sub atan { atan2($_[0],1) };
sub substring {
	my ($string,$index,$len)=@_;
	$string=streval($string);
	return "\"".(substr $string,evaluate($index),evaluate($len))."\"";
}
sub len{
	return length(streval(shift));
}
sub left{
	my ($string,$index)=@_;
	return substring($string,0,$index)
}
sub right{
	my ($string,$index)=@_;
	$index=evaluate($index);
	return substring($string,$index,len($string)-$index-1)
}
sub mid{
	my ($string,$index,$index2)=@_;
	$index=evaluate($index);$index2=evaluate($index2);
	return substring($string,$index,$index-$index2-1)
}
sub streval{
	my $str=shift;
	if ($str=~m/^\s*\"([^\"]*)\"\s*$/) {$str = $1}
	else {$str = evaluate($str)};
	$str=~s/\"([^\"]*)\"/$1/g;
	return $str;
}

}

sub WAIT{
	my $seconds=evaluate(shift);
	if ($seconds) {select(undef, undef,undef, $seconds )};
	logLine("\n...Waiting $seconds");	
}

sub IF{
	my $rest=shift;
	pushPC(findEndif($pC)-1);
	if(!evaluate($rest)){
		logLine("\n...Condition is FALSE at $pC");
		$pC=skipNext($pC)-1;
		logLine("\n...skip to $pC");
	}
	else {
		logLine("\n...Condition is True at $pC");
		if (command($pC+1)=~m/\{/) { #cluster follows
			$pC++}
		else { # bare statement follows
		    lineParse($pC+1,"run"); # execute single statement
			$pC=popPC();
			};
	}
	return $pC;
}

sub ELSE{
    
}

sub ELSEIF{
	my $rest=shift;
	if(!evaluate($rest)){
		logLine("\n...Condition is FALSE at $pC");
		$pC=skipNext($pC)-1;
		logLine("\n...skip to $pC");
	}
	else {
		logLine("\n...Condition is True at $pC");
		if (command($pC+1)=~m/\{/) { #cluster follows
			$pC++}
		else { # bare statement follows
		    lineParse($pC+1,"run"); # execute single statement
			$pC=popPC();
			};
	}
	return $pC;	
}

sub WHILE{
	my $rest=shift;
	if(!evaluate($rest)){
		logLine("\n...Condition is FALSE");
		if ($statements[$pC+1]=~m/\{/){
			logLine("\n...Cluster follows");
			$pC=nextClose($pC+1);
			logLine("\n...Skip to ".(1+$pC));
		}
		else{
			logLine("\n...Single Statement follows");
			logLine("\n...Skip to ".($pC+2)); #needs to be enveloped in brackets
		} 
	}
	else {
		logLine("\n...Condition is True");
		if ($statements[$pC+1]=~m/\{/){ 
			pushPC($pC-1); #come back to while at end of bracket
			$pC++;	#but jump over bracket
		}
		else {
			lineParse($pC+1,"run"); # excute singel statement
			$pC--; #but come back to while test
		}
	}
	return $pC;
}

sub TIMES{
	logLine("\n...TIMES; $pC next Command at line ".($pC+1)." is ".command($pC+1));
	my $times=evaluate(shift);
	
	if (command($pC+1) =~m/\{/){
		pushPC(nextClose($pC+1)+1);
		logLine("\n...Cluster follows, pushing ".($pC+1)." to stack $times times");
		while ($times>1){
			pushPC($pC+1);
			$times--;
		}
	}
	else {
		logLine("\n...Bare statement follows, running line ".(1+$pC)." $times times");
		while ($times>0){lineParse($pC+1,"run");$times--}
		}
}

sub LET{
	my $rest=shift;
	$rest =~m/^\s*([a-z][a-z0-9]*)(\[[^=]*\])?\s*\=\s*(\S.*)/i;
	my $varName=$1;my $arrayIndex=$2;my $rest=$3;
	logLine(" LET $varName $arrayIndex = $rest");
	if ($arrayIndex ne ""){
		$arrayIndex=~s/^\[//;$arrayIndex=~s/\]$//;
		my $tmp=evaluate($rest);
		if (($tmp == 0) && ($tmp ne "0")) {$tmp="\"".$tmp."\"";} 
		$gV{$varName}[evaluate($arrayIndex)]=$tmp;
	}
	elsif ($rest=~m/^(\(\)|\(([^,]+)(,[^,]+)*\))/){
		logLine("\n...$varName is an array $rest ");	
		$rest=~s/^\(//;$rest=~s/\)\s*$//;
		my @tmp = split(",",$rest);
		if ($rest=~m/,/){
			my $c=0;
			foreach (@tmp){
				$tmp[$c]=evaluate($tmp[$c]);
				if (($tmp[$c] == 0) && ($tmp[$c] ne "0")) {$tmp[$c]="\"".$tmp[$c]."\"";}
				$c++;	
			}
		}
		$gV{$varName}=[@tmp];
		logLine("..which contains ".join(",",@{$gV{$varName}}));	
	}
	else{
		my $tmp=evaluate($rest);
		if ($tmp =~m/Array \((.*)\)$/){
			$gV{$varName}=[split(",",$1)];
			logLine("\n...$varName is now..".join(",",@{$gV{$varName}}));	
			return;
		}
		elsif (($tmp == 0) && ($tmp ne "0")) {$tmp="\"".$tmp."\"";}  # handle strings
		$gV{$varName}=$tmp;
		logLine("\n...$varName is now..".$gV{$varName});	
		}	
	
}

sub LOGGING{
	$logging =(shift =~m/off|0/)?0:1;
}
sub FIO{
	$fio =(shift =~m/off|0/)?0:1;
}

sub CLEAR{
	my @toClear=shift;
	foreach my $what (@toClear){
       if($what=~m/gpioLogs/i){
		   GPIO("clear");
	   }
	}
}

sub PUSH{
	my $tmp=shift;
	if ($tmp=~m/^\s*\"([^\"]*)\"\s*$/){
		push (@dataStack,$1);
		logLine("\n...Pushing $1 to dataStack");
	}
	else {push (@dataStack,evaluate($tmp));
	     logLine("\n...Pushing $tmp to dataStack");}	
}

sub POP{
	my $rest=shift;
	my $tmp=pop @dataStack;
	#if (($tmp == 0) && ($tmp ne "0")) {$tmp="\"".$tmp."\"";} 
	if ($rest=~m/^\s*([a-z][a-z0-9\[\]]*)\s*$/i){
		logLine("\n...popping $tmp into $1 from dataStack");
		$gV{$1}=$tmp;		
	}
	else {return $tmp}
}

sub SHOWMENU{
	$showMenu =(shift =~m/off|0/)?0:1;
    logLine("\n...Menu ".($showMenu?"activated":"deactivated"));
}
sub NEED{
	my @vars=split(",",shift);
	logLine("\n...Local vars ".join(",",@vars));
	foreach my $var (@vars){
		POP($var);
	}
}

sub SCREEN{
}
sub LABEL{ # handled in preprocessing
}
sub LIBRARY{ # handled in preexecution
}

sub GOTO{
	my $label=shift;
	logLine("\n...Going to $label  ".$labels{"LABEL$label"} );
	$pC=$labels{"LABEL$label"}?$labels{"LABEL$label"}:evaluate($label);
}

sub GOSUB{
	my $rest=shift; #name of routine followed parameters passed, each separated by a comma
	$rest=~s/^\s*([a-z][a-z0-9]*)(\s(\S.*))?$/$3/i;$sub=$1;
	if (command($labels{"SUB$sub"}) ne "SUB"){
		logLine("\n...Subroutine $sub is not found");
		return;
	}
	if ($rest=~m/\S/) {
		logLine("\n...Parameters $rest found");
		@params=split(",",$rest);
		foreach (@params){
			PUSH($_);
		}
	}
	logLine("\n...Gosubbing to $sub");
	if (command($labels{"SUB$sub"}+1)=~m/\{/){
		logLine("\n...cluster found pushing current to Stack,");
		pushPC();
		$pC=$labels{"SUB$sub"}+1;#point to Bracket
		logLine("\n...pointing to  ".($labels{"SUB$sub"}+1));
	}
	else {lineParse($labels{"SUB$sub"}+1,"run")}#execute statement
	  
}

sub SUB{ # if encountered just skip next cluster or statement 
	if (command($pC+1)=~m/\{/){
		$pC=nextClose($pC+1);
	}
	else {$pC++}
}

sub SHELL{
	my $shCom=shift;
	logLine("\n...Executing ShellCommand : -" . $shCom);
	my $res= `cd $scriptFolder && $shCom 2>&1`;
	chomp $res;
	$res =~s/\n/\n..>/g;
	logLine("\n...Report: -$res ");
}

sub PRINT{
	my $toPrint=shift;
	if ($toPrint=~m/^\s*\"([^\"]*)\"\s*$/){
		$toPrint=~s/\"([^\"]*)\"/$1/g;
		}
	else {
		$toPrint = evaluate($toPrint);
	}
	$toPrint=~s/\"([^\"]*)\"/$1/g;
	$prStyle=~s/\"//g;
	$Console.="<div style=\"".$prStyle."\">$toPrint</div>";
	$prStyle="";
}
sub ORIGIN{
	my ($x,$y)=split(",",shift);
	$gV{"ORIGINX"}=evaluate($x);
	$gV{"ORIGINY"}=evaluate($y);
}
sub SCALE{
	my ($x,$y)=split(",",shift);
	$gV{"SCALEX"}=evaluate($x);
	$gV{"SCALEY"}=evaluate($y);
}
sub PLOT{
	my ($x,$y)=split(",",shift);
	$x=($gV{"SCALEX"}*evaluate($x))+$gV{"ORIGINX"};
	$y=$gV{"ORIGINY"}-($gV{"SCALEY"}*evaluate($y));
	AT("$x,$y");	
	$Console.="<div style=\"".$prStyle."\">*</div>";
	$prStyle=~s/\"//g;
	logLine("\n...Plotting $x , $y"); 
	$prStyle=~s/position.*nowrap;//;
}
sub AT{
	my ($x,$y)=split(",",shift);
	$x=evaluate($x);$y=evaluate($y);
	$prStyle=~s/position.*nowrap;//;
	$prStyle.="position:absolute;left:".$x."px;top:".$y."px;white-space: nowrap;";
	logLine("\n...style is now $prStyle"); 	
}
sub COLOR{
	$color=shift;
	$color=(evaluate($color) eq "")?$color:evaluate($color);
	$prStyle=~s/color[^;]*;//;
	$prStyle.="color:$color;";
	logLine("\n...style is now $prStyle"); 	
}
sub ROTATE{
	my $rotate=shift;
	$prStyle=~s/(-[a-z]*-)*transform[^;]*;//g;
	$prStyle.="-moz-transform:rotate(".$rotate."deg);-webkit-transform:rotate(".$rotate."deg);-o-transform:rotate(".$rotate."deg);-ms-transform:rotate(".$rotate."deg);";
	logLine("\n...style is now $prStyle"); 	
}
sub SIZE{
	my $size=shift;
	$prStyle.="font-size:$size;";
	logLine("\n...style is now $prStyle"); 	
}
sub EXIT{
	logLine("\n...Level is ".getBracLevel($pC));
	my $check=nextClose($pC);
	logLine(($check < $end)?("\n...EXIT to  ".(1+$check)):"\n...EXIT Program  ");
}

sub OPENBRACKET{
	my $line=shift;
#	logLine("\n...Level is ".getBracLevel($line));
#	my $check=nextClose($line);
#	logLine("\n...".(($check=~m/Error/)?$check:"Next matched } is ".$check));
	pushPC(1+nextClose($line));
	return $line;
}
sub CLOSEBRACKET{
#	my $line=shift;
#	logLine("\n...Level is ".getBracLevel($line));
#	my $check=lastOpen($line);
#	logLine("\n...".(($check=~m/Error/)?$check:"Last matched { is ".($check)));	
	return popPC();
}
sub nextClose{
	my $ln=shift;
	my $bLevel=getBracLevel($ln);
	$ln++;
	while ($bLevel < getBracLevel($ln)){
		if ($ln > $end) {return "Error: No matching close Brackets"};
		$ln++;
	}
	return $ln	
}
sub lastOpen{
	my $ln=shift;
	my $bLevel=getBracLevel($ln);
	if ($bLevel < 0) {return "Error: No matching open Brackets"};
	$ln--;
	while ($bLevel != getBracLevel($ln)){
		$ln--;
	}
	return $ln	
}

sub findEndif{
	my $ln=shift;
	my $next=1;
	while ($next){
		$ln=skipNext($ln);
		logLine("\n...Found ".command($ln));
		if (command($ln) =~m/^(elseif|else)$/i){
			logLine("\n...Found $1, skipping");
		}
		else{$next=0}
		
		}
	return $ln;
}

sub skipNext{ #skip next statement or cluster of statements
	my $ln=shift;
	my $nextCommand=command($ln+1);
	logLine("\n...Skip from $ln over $nextCommand to ");
	if ($nextCommand =~m/\{/) {
		$ln=nextClose($ln+1)+1;
	}
	else {$ln+=2};
	logLine("$ln");
	return $ln;
}


sub pushPC{
	my $push=shift;
	if (!$push && ($push ne "0") ){$push = $pC;}
	push (@pCStack,$push);
	logLine("\n...Push $push to stack - ".join(",",@pCStack));
}
sub popPC{
	my $tpC=pop (@pCStack);
	if (!$tpC) {logLine("\n...Error stack is empty".join(",",@pCStack));}
	else {logLine("\n...pop $tpC from stack ".join(",",@pCStack));}
	return $tpC;
}

sub load{
		if (($file eq "")||(! -e $scriptFolder.$file)) {
			logLine("ERROR!: -File $file Not Found; Exit at $timeStamp");
			return 0;
		}
		logLine("File $file Found; loaded on ".localtime($timeStamp));
		return loadFile($file);
}

sub loadFile{
	my $file=shift;
	my $row="";
	open (FILE,"<$scriptFolder$file") || return "Can't load  $scriptFolder$file $!";
	while (<FILE>){
		$row.=$_;
	}
	close FILE;
	return $row;
}

sub saveFile{
	my ($file,$data)=@_;
	open (FILE,">$scriptFolder$file") ||logLine("ERROR...Can't create  $scriptFolder$file $!");
	print FILE $data;
	close FILE;
}

sub logLine{
	unless ($logging) {return;}
	my $logLine=shift;
	$logs.=$logLine;
	my $filesize = -s $scriptFolder.$file.".log";
	if ($filesize < 10000) {
		open (FILE,">>$scriptFolder$file".".log");
		print FILE $logLine;
		close FILE;
	}
}


sub validPin{
	my $pinToCheck=shift;
	my $found=0;
	my $pinCount=@gpioPins;
	while ((!$found)&&($pinCount>0)){
		$pinCount--;
		if ($gpioPins[$pinCount] == $pinToCheck){$found=1}	
	}
	logLine("\n...Pin $pinToCheck is ".($found?"":"not ")."valid");
	return $found?$pinCount+1:0;
}



sub GPIO{
	my $tmp=shift;chomp $tmp;
	if ($tmp =~m/clear/i){
		saveFile(".gpioLogs",lastLogEntry(".gpioLogs"));
		logLine("\n...Clearing GPIO Logs");
		return;
	};
	logLine("\n...GPIO with $tmp");
	my %submissions=();
	my @submits=(); 
	@submits=split(/[\n\-]/,$tmp);
	foreach(@submits){
		my $line = $_;
		$line=~s/:.*$//;
		$submissions{$line} = $_;
	}
	my $multiData="";
	
	my $pinLogLine=$timeStamp."-";
	my $pinCount=@gpioPins;
	
	for (my $count=0;$count<$pinCount;$count++){
		my ($pnl,$mdl,$ctl,$dtl)=split(":",$gpioData[$count]);
		$pnl=$gpioPins[$count];
		if ($submissions{$pnl}){ # if there has been a submission
			my ($pns,$mds,$cts,$dts)=split(":",$submissions{$pnl});
			if (($mdl ne $mds)&&($mds=~m/in|out|pwm/)){
				$mdl=$mds;
				`/usr/local/bin/gpio -g mode $pnl $mds`;
			};  #set new mode
			if (($ctl ne $cts)&&($cts=~m/up|down|tri/)){
				$ctl= $cts;
				`/usr/local/bin/gpio -g mode $pnl $cts`;  #set new control
			}
			if ($mdl eq "out"){
				$dtl=$dts;
				`/usr/local/bin/gpio -g write $pnl $dts`;
			}
			elsif ($mdl eq "pwm"){
				$dtl=$dts;
				`/usr/local/bin/gpio -g pwm $pnl dts`;
			}
		}
		if ($mdl eq "in"){
				$dtl = `/usr/local/bin/gpio -g read $pnl`;
		}
		$pinLogLine.=(($dtl=~m/\d+/)?$dtl:"?").":";
		$gpioData[$count]=$pnl.":".($mdl?$mdl:"?").":".($ctl?$ctl:"?").":".$dtl;
		$gpioData[$count]=~s/[\n\r]//g;
		
		$multiData.=$dtl;
	}
	$fioBuffer=join("\n",@gpioData);
	if (!$fio){
		saveFile(".gpioFile",$fioBuffer);
		$pinLogLine=~s/[\s\n]//g;
		#Only save to log if the data has changed;
		my $lastEntry=lastLogEntry(".gpioLogs");
		if ( (split("-",$pinLogLine))[1] ne (split("-",$lastEntry))[1]  ){
			saveLogs($pinLogLine);
		}
	}
	$multiData=~s/[^\d]//g;
	logLine("\n...returning from GPIO with $multiData");
	return $multiData;
	
sub saveLogs{
	my ($newData)=@_;
	my $oldFile="";
	if (-e $scriptFolder.".gpioLogs"){
		$oldFile=loadFile(".gpioLogs");
		saveFile(".gpioLogs.tmp",$oldFile);
	}
   	my $newFile=$newData."\n".$oldFile;
   	saveFile(".gpioLogs",$newFile);
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
}


sub toTable{
	my ($title,$content)=@_;
	return "<table class=status border=1><tr><th>$title</th></tr><tr><td><table class=statusContent><tr><td>$content</td></tr></table></td></tr></table>";
}

sub progView{
	my $edit= ($file =~m/\.pgl$/i)?"<span class=\"btn right\" onclick=\"piStatus('edit','$file')\">Edit</span>":"";
	$Console="<div class=absolute>".$Console."</div>";
	my $firstShow= ($Console eq "")?$Listing:$Console;
	

return toTable(($showMenu?'<span class="btn left" onclick=\'divText("Prog","'.toHTMLCode($Listing).'")\'>List</span>'.$edit.
               ($logging?'<span class="btn left" onclick=\'divText("Prog","'.toHTMLCode($logs).'")\'> Logs</span>':'').
               '<span class="btn left" onclick=\'divText("Prog","'.toHTMLCode($Console).'")\'>Console</span>':''),
               "<div id=Prog class=shell>".escapeCode($firstShow)."</div>");

}

sub escapeCode{
	my $str=shift;
	 $str=~s/\n/<br>/g;
     $str=~s/'/\'/g;
     $str=~s/"/\"/g;
	return $str;
}

sub toHTMLCode{
	my $str=shift;
	 $str=~s/\n/<br>/g;
     $str=~s/'/&#92&#44;/g;
     $str=~s/"/&#92&#34;/g;
	return $str;
}

sub about{
		 @uname=split(" ",`uname -a`);
		 $uname[4].="<br>";
		 $uname[10].="<br>";
		 return toTable("piGears has loaded successfully",
		           "<center>".join(" ",@uname)."<br><br>piGears Version $version <br>Copyleft Under GPL 2.0+<br>".
		           "Saif Ahmed<br>".
		           "More Info:<a href=http://www.windon.themoon.co.uk/NVSM/piGears target=_new>Web GPIO Programming</a></center>") ;	
}

if ($status eq "") {
	$status="piGears exited without report<br>";
	$status.="Parameters=$Parameters<br>";
	$status.="reqURI=$reqURI<br>";
	$status.="scriptFolder=$scriptFolder<br>";
	$status.="Errors=$errors<br>";
	unless ($hasGpio) {$status.= "<br>wiringPi appears not to be installed"};
	}


print <<END_HTML;
<html>
<title>piGears - Raspberry Pi Web Programmed IO</title>
<head>
</head>
<body>
<div class="main">$status</div>
<div class=debug>$debugScript</div>
</body>
</html>
END_HTML



