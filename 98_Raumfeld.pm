#####################################################################################
#     98_Raumfeld.pm
#
#     This file can be used with Fhem.
#
#     Fhem is free software: you can redistribute it and/or modify
#     it under the terms of the GNU General Public License as published by
#     the Free Software Foundation, either version 2 of the License, or
#     (at your option) any later version.
#
#     Fhem is distributed in the hope that it will be useful,
#     but WITHOUT ANY WARRANTY; without even the implied warranty of
#     MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#     GNU General Public License for more details.
#
#     You should have received a copy of the GNU General Public License
#     along with Fhem.  If not, see <http://www.gnu.org/licenses/>.
#
####################################################################################
#     Usage
#
#     define <name> Raumfeld <ip-address>
#     
#     Raumfeld (c) Rainer Zeifang / https://github.com/rainerz1964/FHEM
#
#     This module provides acccess in FHEM to a Teufel Raumfeld system using the 
#     node-raumserver as provided in https://github.com/ChriD/node-raumserver
#     
# 
#
#####################################################################################

package main;
use strict;
use warnings;
use HttpUtils;
use Encode;
use JSON;
use Data::Dumper;
use URI::Escape;

my $logLevel = 6;

my %Raumfeld_gets = (
	"title" => "xx",
	"volume" => 0,
    "station" => "SWR3",
    "power" => "off",
    "rooms" => " "
);


my %Raumfeld_StationList = (
    "SWR1" => "http://addrad.io/4WRLzh",
    "SWR3" => "http://addrad.io/4WRLM9",
    "OE3"  => "https://oe3shoutcast.sf.apa.at:443",
    "Ö3"  => "https://oe3shoutcast.sf.apa.at:443",
    "NDR2" => "http://ndr-ndr2-niedersachsen.cast.addradio.de/ndr/ndr2/niedersachsen/mp3/128/stream.mp3"
);

sub Raumfeld_Initialize($) {
    my ($hash) = @_;

    $hash->{DefFn}      = 'Raumfeld_Define';
    $hash->{UndefFn}    = 'Raumfeld_Undef';
    $hash->{SetFn}      = 'Raumfeld_Set';
    $hash->{GetFn}      = 'Raumfeld_Get';
    $hash->{AttrFn}     = 'Raumfeld_Attr';
    $hash->{ReadFn}     = 'Raumfeld_Read';

    $hash->{AttrList} = $readingFnAttributes;
    $hash->{parseParams}=1;
}

sub Raumfeld_Define($$$) {
    my ($hash, $a, $h) = @_;
    
    if(int(@$a) < 3) {
        return "too few parameters: define <name> Raumfeld <URL of Raumserver>";
    }

    $hash->{url} = @$a[2];
    my $name = @$a[0];

    if($init_done && !defined($hash->{OLDDEF})) {
		# setting stateFormat
	 	$attr{$name}{"stateFormat"} = "defined";
 	}

    Raumfeld_Update ($hash);
    return undef;
}


##############################################################################
# Raumfeld_GetRooms
#
# reads all nexcessary content in a Raumfeld system
#
###############################################################################

sub Raumfeld_GetRooms($) {
    my ($hash) = @_;
    my $name = $hash->{NAME};
    my $urlAddress = $hash->{url};
    my $request = $urlAddress . "/raumserver/data/getZoneConfig";
    Log3 ($name, $logLevel, "Raumfeld GetRooms with request: $request");
    my $param = {
                url        => $request,
                timeout    => 5,
                hash       => $hash,
                method     => "GET",
                header     => "User-Agent: FHEM\r\nAccept: application/json",
                callback   => \&Raumfeld_GetRoomsCallback
    };
    HttpUtils_NonblockingGet ($param);
}

sub Raumfeld_GetRoomsCallback($$$) {
    my ($param, $err, $body) = @_;
    my $hash    = $param->{hash};
    my $name    = $hash->{NAME};
    Log3 $name, 3, "$name: GetRoomsCallback: Error: $err" if ($err);
    if ($err) {
        return;
    }
    my $jsonData = encode_utf8($body);
    my $result = decode_json($jsonData);
    if ($result->{'error'} eq 'true') {
        Log3 ($name, 3, "$name: GetRoomsCallback: request returns error in response body");
        return;
    }   
    my $dataArray = $result->{'data'}{'zoneConfig'}{'zones'}[0]{'zone'};
    my @rooms = ();
    foreach (@$dataArray) {
        push ( @rooms, $_->{'room'}[0]{"\$"}{'name'} ); 
    }
    
    my $roomsText = join (",", @rooms);
    readingsBeginUpdate($hash);
    readingsBulkUpdateIfChanged ($hash, 'rooms', $roomsText, 1);
    readingsBulkUpdate ($hash, '.rooms', \@rooms, 0);
    readingsEndUpdate($hash, 1);
    Log3 ($name, $logLevel, "Raumfeld GetRooms: Success: ");
    Log3 ($name, $logLevel, Dumper (\@rooms));
    Raumfeld_GetUpdate ($hash, \@rooms);
}


##############################################################################
# Raumfeld_Update
#
# reads the current settings of a Raumfeld system
#
###############################################################################


sub Raumfeld_Update ($) {
    my ($hash) = @_;
    Raumfeld_GetFavorites ($hash);
    Raumfeld_GetRooms ($hash);
}


##############################################################################
# Raumfeld_GetUpdate
#
# reads volume, titles and power state of a Raumfeld system and stores it
# to internal variables that can be later accessed by ReadingsVal
#
###############################################################################

sub Raumfeld_GetUpdate($$) {
    my ($hash, $rooms) = @_;
    my $name = $hash->{NAME};
    my $urlAddress = $hash->{url};
    my $request = $urlAddress . "/raumserver/controller/getRendererState";
    Log3 ($name, $logLevel, "Raumfeld GetUpdate with request: $request");
    my $param = {
                    rooms      => \@$rooms,
                    url        => $request,
                    timeout    => 5,
                    hash       => $hash,
                    method     => "GET",
                    header     => "User-Agent: FHEM\r\nAccept: application/json",
                    callback   => \&Raumfeld_GetUpdateCallback
    };  
    HttpUtils_NonblockingGet ($param);
}

sub Raumfeld_GetUpdateCallback($$$) {
    my ($param, $err, $body) = @_;
    my $hash    = $param->{hash};
    my $name    = $hash->{NAME};
    my $rooms   = $param->{rooms};
    Log3 $name, 3, "$name: callback ReadVolumes: Error: $err" if ($err);
    if ($err) {
        return;
    }
    my $jsonData = encode_utf8($body);
    my $result = decode_json($jsonData);
    if ($result->{'error'} eq 'true') {
        Log3 ($name, 3, "$name: callback ReadVolumes: request returns error in response body");
        return;
    }
    my $dataArray = $result->{'data'};
    my %volumes;
    my %powers;
    my %titles;
    foreach (@$dataArray) {
        my $volume = $_->{'Volume'};
        my $power = $_->{'rooms'}[0]{'PowerState'};
        my $room = $_->{'rooms'}[0]{'name'};
        my $id = $_->{'mediaItem'}{'id'};
        foreach (@$rooms) {
            if (not exists $titles{$room}) {
                $titles{$room} = "";
            }
            if ($_ eq $room) {
                $volumes{$room} = $volume;
                if (defined $id) {
                    $titles{$room} = Raumfeld_IdToTitle($hash, $id);
                }
                Log3 ($name, $logLevel, "titles of room $room:  $titles{$room}");
                if (index($power, 'STANDBY') != -1) {
                    $powers{$room} = 'off';
                } elsif (index($power, 'ACTIVE') != -1) {
                    $powers{$room} = 'on';
                }
            }
        }
    }

    readingsBeginUpdate($hash);
    # Update volumes
    readingsBulkUpdate ($hash, '.volumes', \%volumes, 0);
    Raumfeld_BulkUpdateReadingsStrings($hash, 'Volume', \%volumes);

    Log3 ($name, $logLevel, "Raumfeld GetUpdateCallback: volumes: ");
    Log3 ($name, $logLevel, Dumper(\%volumes));

    # Update power states
    readingsBulkUpdate ($hash, '.powers', \%powers, 0);
    Raumfeld_BulkUpdateReadingsStrings($hash, 'Power', \%powers);
 
    Log3 ($name, $logLevel, "Raumfeld GetUpdateCallback: power states: ");
    Log3 ($name, $logLevel, Dumper(\%powers));

    # Update titles
    readingsBulkUpdate ($hash, '.titles', \%titles, 0);
    Raumfeld_BulkUpdateReadingsStrings($hash, 'Title', \%titles);
    
    Log3 ($name, $logLevel, "Raumfeld GetTitles: Success: ");
    Log3 ($name, $logLevel, Dumper(\%titles));

    readingsEndUpdate ($hash, 1);
}

sub Raumfeld_BulkUpdateReadingsStrings ($$$) {
    my ($hash, $readingsExt, $hashes) = @_;
    foreach my $key (keys %$hashes) {
        my $reducedKey = $key;
        $reducedKey =~ s/ +//g;
        readingsBulkUpdateIfChanged ($hash, $reducedKey . $readingsExt, $hashes->{$key});
    }
}


sub Raumfeld_IdToTitle ($$) {
    my ($hash, $id) = @_;
    my $favorites = ReadingsVal ($hash->{'NAME'}, '.favorites', 99);
    if ($favorites ne 99) {
        foreach (@$favorites) {
            if ($_->{'id'} eq $id) {
                Log3 ($hash->{'NAME'}, $logLevel, "Title found: $_->{'title'} for id: $id");
                return $_->{'title'};
            }
        }
    }   
    return "";
}

##############################################################################
# Raumfeld_GetUpdate
#
# reads Favourites of a Raumfeld system and stores it
# to internal variables that can be later accessed by ReadingsVal
#
###############################################################################


sub Raumfeld_GetFavorites ($) {
    my ($hash) = @_;
    my $name = $hash->{NAME};
    my $urlAddress = $hash->{url};
    # my $request = $urlAddress . "/raumserver/data/getMediaList?id=0%2FRadioTime%2FFavorites%2FMyFavorites";
    my $request = $urlAddress . "/raumserver/data/getMediaList?id=0%2FFavorites%2FMyFavorites";
    Log3 ($name, $logLevel, "Raumfeld GetFavorites with request: $request");
    my $param = {
                url        => $request,
                timeout    => 5,
                hash       => $hash,
                method     => "GET",
                header     => "User-Agent: FHEM\r\nAccept: application/json",
                callback   => \&Raumfeld_ReadFavorites
    };
    HttpUtils_NonblockingGet ($param);
}

sub Raumfeld_ReadFavorites($$$) {
    my ($param, $err, $body) = @_;
    my $hash    = $param->{hash};
    my $name    = $hash->{NAME};
    Log3 $name, 3, "$name: callback ReadFavorites: Error: $err" if ($err);
    if ($err) {
        return;
    }
    my $jsonData = encode_utf8($body);
    my $result = decode_json($jsonData);
    if ($result->{'error'} eq 'true') {
        Log3 ($name, 3, "$name: callback ReadFavorites: request returns error in response body");
        return;
    }
    my $dataArray = $result->{'data'};
    
    my $titles ="";
    foreach (@$dataArray) {
        if ($titles eq "") {
            $titles = $_->{'title'};
        } else {
            $titles = $titles . "," . $_->{'title'};
        }
    }
    readingsBeginUpdate($hash);
    readingsBulkUpdate ($hash, '.favorites', $dataArray, 0);
    readingsBulkUpdateIfChanged ($hash, 'Favorites', $titles, 1);
    readingsEndUpdate($hash, 1);
    Log3 ($name, $logLevel, "Raumfeld GetFavorites: Success: $titles");
}

##############################################################################
# Raumfeld_SetVolume
#
# set volume of a given room
#
################################################################################


sub Raumfeld_SetVolume($$$) {
    my ($hash, $room, $volume) = @_;
    my $name = $hash->{NAME};
    my $urlAddress = $hash->{url};
    my $request = $urlAddress . "/raumserver/controller/setVolume?id=" . uri_escape($room) . "&value=" . $volume . "&scope=room";
    Log3 ($name, $logLevel, "Raumfeld SetVolume with request: $request");
    my $param = {
                    room       => $room,  
                    volume     => $volume,
                    url        => $request,
                    timeout    => 5,
                    hash       => $hash,
                    method     => "GET",
                    header     => "User-Agent: FHEM\r\nAccept: application/json",
                    callback   => \&Raumfeld_SetVolumeCallback
    };  
    HttpUtils_NonblockingGet ($param);
}

sub Raumfeld_SetVolumeCallback($$$) {
    my ($param, $err, $body) = @_;
    my $hash    = $param->{hash};
    my $name    = $hash->{NAME};
    Log3 $name, 3, "$name: SetVolumeCallback: Error: $err" if ($err);
    if ($err) {
        return;
    }
    my $jsonData = encode_utf8($body);
    my $result = decode_json($jsonData);
    if ($result->{'error'} eq 'true') {
        Log3 ($name, 3, "$name: SetVolumeCallback: request returns error in response body");
        return;
    }
    my $volumes = ReadingsVal ($name, '.volumes', 1);
    my $currentRoom = ReadingsVal ($name, 'currentRoom', "");
    $volumes->{$param->{'room'}} = $param->{'volume'};

    readingsBeginUpdate($hash);
    readingsBulkUpdate ($hash, '.volumes', $volumes, 0);
    Raumfeld_BulkUpdateReadingsStrings($hash, 'Volume', $volumes);

    if ($currentRoom eq $param->{'room'}) {
        readingsBulkUpdate ($hash, 'currentVolume', $param->{'volume'}, 1);
    }
    readingsEndUpdate($hash, 1);

    Log3 ($name, $logLevel, "Raumfeld SetVolume: Success: ");
    Log3 ($name, $logLevel, Dumper ($volumes));
}

##############################################################################
# Raumfeld_SetPower
#
# set power of a room
#
###############################################################################

sub Raumfeld_SetPower($$$) {
    my ($hash, $room, $power) = @_;
    my $name = $hash->{NAME};
    my $urlAddress = $hash->{url};
    my $request = "";
    my $currentRoom = ReadingsVal ($name, 'currentRoom', "");
    my $powers = ReadingsVal ($name, '.powers', 0);

    if ($power eq "on") {
        $request = $urlAddress . "/raumserver/controller/leaveStandby?id=" . uri_escape($room) . "&scope=room";
    } elsif ($power eq "off") {
        $request = $urlAddress . "/raumserver/controller/enterAutomaticStandby?id=" . uri_escape($room) . "&scope=room";
    }

    if ($request ne "")
    {
        $powers->{$room} = $power;
        Log3 ($name, $logLevel, "Raumfeld SetPower with request: $request");
        my $param = {
                    url        => $request,
                    timeout    => 5,
                    hash       => $hash,
                    method     => "GET",
                    header     => "User-Agent: FHEM\r\nAccept: application/json",
                    callback   => sub($$$){}
        };  
        HttpUtils_NonblockingGet ($param);

        readingsBeginUpdate ($hash);
        readingsBulkUpdate ($hash, '.powers', $powers, 0);
        Raumfeld_BulkUpdateReadingsStrings($hash, 'Power', $powers);

        if ($currentRoom eq $room) {
            readingsBulkUpdate ($hash, 'currentPower', $power, 1);
        }   
        readingsEndUpdate($hash, 1);
    }
    
    
    
}


##############################################################################
# Raumfeld_SetTitle
#
# set title of a room
#
###############################################################################


sub Raumfeld_SetTitle($$$) {
    my ($hash, $room, $title) = @_;
    my $name = $hash->{NAME};
    my $urlAddress = $hash->{url};
    my $station = Raumfeld_FindStation ($title);
    my $container = Raumfeld_FindContainer ($hash, $title);
    my $request = "";
    
    if ($container ne "") {
        $request = $urlAddress . "/raumserver/controller/loadSingle?id=" . uri_escape($room) . "&value=" . uri_escape($container) ;
    } elsif ($station ne "") {
        $request = $urlAddress . "/raumserver/controller/loadUri?id=" . uri_escape($room) . "&value=" . uri_escape($station) ;
    } else {
        $request = $urlAddress . "/raumserver/controller/loadUri?id=" . uri_escape($room) . "&value=" . uri_escape($title) ;
    }
    Log3 ($name, $logLevel, "Raumfeld SetTitle with request: $request");
    my $param = {
                    room       => $room,  
                    title      => $title,
                    url        => $request,
                    timeout    => 5,
                    hash       => $hash,
                    method     => "GET",
                    header     => "User-Agent: FHEM\r\nAccept: application/json",
                    callback   => \&Raumfeld_SetTitleCallback
    };  
    HttpUtils_NonblockingGet ($param);
}


sub Raumfeld_FindStation ($) {
    my ($station) = @_;
    foreach my $key (keys %Raumfeld_StationList) {
        if (index($key, $station) != -1) {
            return $Raumfeld_StationList{$key};
        }
    }
    return "";
}

sub Raumfeld_FindContainer ($$) {
    my ($hash, $title) = @_;
    my $favorites = ReadingsVal ($hash->{NAME}, '.favorites', 0);
    foreach (@$favorites) {
        if (index($_->{'title'}, $title) != -1) {
            return $_->{id};
        }
    }
    return "";
}

sub Raumfeld_SetTitleCallback($$$) {
    my ($param, $err, $body) = @_;
    my $hash    = $param->{hash};
    my $name    = $hash->{NAME};
    Log3 $name, 3, "$name: SetTitleCallback: Error: $err" if ($err);
    if ($err) {
        return;
    }
    my $jsonData = encode_utf8($body);
    my $result = decode_json($jsonData);
    
    if ($result->{'error'} eq 'true') {
        Log3 ($name, 3, "$name: SetTitleCallback: request returns error in response body");
        return;
    }
    Log3 ($name, $logLevel, "Raumfeld SetTitle: Successfully Set Title");

    my $titles = ReadingsVal ($name, '.titles', 0);
    $titles->{$param->{'room'}} = $param->{'title'};

    readingsBeginUpdate ($hash);
    readingsBulkUpdate ($hash, '.titles', $titles, 0);
    Raumfeld_BulkUpdateReadingsStrings($hash, 'Title', $titles);
    
    readingsEndUpdate($hash, 1);

    Raumfeld_Play ($hash, $param->{'room'});
}

##############################################################################
# Raumfeld_Play
#
# Play a room
#
###############################################################################


sub Raumfeld_Play ($$) {
    my ($hash, $room) = @_;
    my $name = $hash->{NAME};
    my $urlAddress = $hash->{url};
    my $request = $urlAddress . "/raumserver/controller/play?id=" . uri_escape($room);
    Log3 ($name, $logLevel, "Raumfeld Play with request: $request");
    my $param = {
                    room       => $room,  
                    url        => $request,
                    timeout    => 5,
                    hash       => $hash,
                    method     => "GET",
                    header     => "User-Agent: FHEM\r\nAccept: application/json",
                    callback   => \&Raumfeld_SetPlayCallback
    };  
    HttpUtils_NonblockingGet ($param);
}

sub Raumfeld_SetPlayCallback($$$) {
    my ($param, $err, $body) = @_;
    my $hash    = $param->{hash};
    my $name    = $hash->{NAME};
    Log3 $name, 3, "$name: SetPlayCallback: Error: $err" if ($err);
    if ($err) {
        return;
    }
    my $jsonData = encode_utf8($body);
    my $result = decode_json($jsonData);
    if ($result->{'error'} eq 'true') {
        Log3 ($name, 3, "$name: SetPlayCallback: request returns error in response body");
        return;
    }
    Log3 ($name, $logLevel, "Raumfeld Play: Successful Play");
}


##############################################################################
# Raumfeld_*
#
# Undef, Get, Set and Attr
#
###############################################################################

sub Raumfeld_Undef($$) {
    my ($hash, $arg) = @_; 
    # nothing to do
    return undef;
}

sub Raumfeld_Get($$$) {
	my ($hash, $a, $h) = @_;
    Raumfeld_Update ($hash);
    my $numberOfParams = int(@$a);
	return '"get Raumfeld" needs at least 2 arguments' if ($numberOfParams < 2);
 
	my $name = @$a[0];
	my $opt = @$a[1];
    my $param3 = @$a[2];
    
	if(!exists ($Raumfeld_gets{$opt})) {
		my @cList = keys %Raumfeld_gets;
		return "Unknown argument $opt, choose one of " . join(" ", @cList);
	}
	
    if (($opt eq "volume") and ($numberOfParams >= 3)) {
        my $volumes = ReadingsVal ($name, '.volumes', 0);
        my $volume = $volumes->{$param3};
        Log3 ($name, $logLevel, "Raumfeld Get Volume returns $volume for $param3");
	    return $volume;
    } elsif (($opt eq "station") and ($numberOfParams >= 3)) {
        my $station = $Raumfeld_StationList{$param3}; 
        Log3 ($name, $logLevel, "Raumfeld Get Station returns $station for $param3");
        return $station;
    } elsif (($opt eq "title")) {
        my $titles = ReadingsVal ($name, '.titles', 0);
        my $title = $titles->{$param3};
        Log3 ($name, $logLevel, "Raumfeld Get Title returns $title for $param3");
        return $title;
    } elsif (($opt eq "power")) {
        my $powers = ReadingsVal ($name, '.powers', 0);
        my $power = $powers->{$param3};
        Log3 ($name, $logLevel, "Raumfeld Get Power returns $power for $param3");
        return $power;
    } elsif (($opt eq "rooms")) {
        my $rooms = ReadingsVal ($name, 'rooms', 0);
        return $rooms;
    }

    return undef;
}

sub Raumfeld_Set($$$) {
	my ($hash, $a, $h) = @_;
    #Raumfeld_Update($hash);
	my $numberOfParams = int(@$a);

	return '"set Raumfeld" needs at least 2 arguments' if ($numberOfParams < 2);
	
	my $name = @$a[0];
	my $opt = @$a[1];
    my $param3 = @$a[2]; # room or station
	my $value = @$a[3];
	
	if(!defined($Raumfeld_gets{$opt})) {
		my @cList = keys %Raumfeld_gets;
		return "Unknown argument $opt, choose one of " . join(" ", @cList);
	}

    if ($opt eq 'volume') {
        Raumfeld_SetVolume ($hash, $param3, $value);
    } elsif ($opt eq 'title') {
        Raumfeld_SetTitle ($hash, $param3, $value);
    } elsif ($opt eq 'station') {
        $Raumfeld_StationList{$param3} = $value;
    } elsif ($opt eq 'power') {
        Raumfeld_SetPower ($hash, $param3, $value);
    } 
    
	return "$opt for $param3 set to $value";
}


sub Raumfeld_Attr(@) {
	my ($cmd,$name,$attr_name,$attr_value) = @_;
	return undef;
}

1;

=pod
=begin html

<h1 id="fhem">FHEM</h1>
<h2 id="raumfeld-module-for-fhem">Raumfeld Module for FHEM</h2>
<h3 id="raumfeld">Raumfeld</h3>
<p><em>Raumfeld_98.pm</em> implements access to a Teufel Raumfeld system via a <a href="https://github.com/ChriD/Raumserver">Raumserver</a>
It reads the various rooms of the system during intialization as well as the Favourites list and allows you to play the elements in the Favourites list in the
corresponding room. It allows as well to change the volume in each room.</p>
<h4 id="define">Define</h4>
<p><code>define &lt;name&gt; Raumfeld &lt;address&gt;</code></p>
<p>Example: <code>define Raumfeld raumfeld http://127.0.0.1:8585</code></p>
<p>The <code>&lt;address&gt;</code> parameter is the address of the Raumserver.</p>
<h4 id="set">Set</h4>
<p><code>set &lt;name&gt; &lt;option&gt; &lt;room&gt; &lt;value&gt;</code>
Options:</p>
<ul>
<li><code>title</code>
Sets either the predefined favorites and plays them or the user defined streams and plays them in a room
<code>set &lt;name&gt; title &lt;room&gt; &lt;value&gt;</code></li>
<li><code>volume</code>
Sets the volume of a room to a new <code>&lt;value&gt;</code>
<code>set &lt;name&gt; volume &lt;room&gt; &lt;value&gt;</code></li>
<li><code>power</code>
Switch the power of a room to <code>&lt;on|off&gt;</code>
<code>set &lt;name&gt; power &lt;room&gt; &lt;on|off&gt;</code></li>
</ul>
<h4 id="get">Get</h4>
<p><code>get &lt;name&gt; &lt;option&gt; &lt;room&gt;</code></p>
<p>You can <code>get</code> the value of any of the options described in
paragraph &quot;Set&quot; above.</p>
<h4 id="readings">Readings</h4>
<p>For usage with FHEM Tablet UI for each room <code>&lt;room&gt;</code> there are three readings available</p>
<ul>
<li><code>&lt;room&gt;Title</code></li>
<li><code>&lt;room&gt;Volume</code></li>
<li><code>&lt;room&gt;Power</code></li>
</ul>
<p>If the room name contains white spaces these are eliminated before building the reading</p>
<p>Two addtional readings are available</p>
<ul>
<li><code>rooms</code>containing a string of a comma separated list with all rooms in the Ruamfeld system</li>
<li><code>Favorites</code> a sting of a comma separated lsit with all Favorties, that can be used as values for setting the <code>title</code></li>
</ul>
<h4 id="attributes">Attributes</h4>
<p>none</p>

=end html

=cut
