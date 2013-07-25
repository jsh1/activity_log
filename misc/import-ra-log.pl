#!/usr/bin/perl

# I used this to convert my data from http://www.runningahead.com/ into
# the plaintext format used by the activity log code. (This reads the
# tab-separated RA format, not the XML format.)

use strict;
use warnings;
use diagnostics;

use File::Basename qw(dirname basename);
use File::Path qw(mkpath);
use Getopt::Long;
use Text::Wrap;
$Text::Wrap::columns = 72;

my $activities_dir = "$ENV{HOME}/Documents/Activities";
my $garmin_dir = "$ENV{HOME}/Documents/Garmin";

my $opt_overwrite = 0;

GetOptions ("overwrite" => \$opt_overwrite);

my $ra_log_file = shift;

my %ignored_types = (
    "Strength" => 1,
);

my %subtype_map = (
    "Easy + Strides" => "easy-strides",
    "Day hike" => "day-hike",
    "Race DNF" => "race-DNF",
);

my %equipment_map = (
    # adidas
    "Mana 5 (blue)" => "mana-5-blue",
    "Mana 5 (white)" => "mana-5-white",
    "Mana 5 (yellow)" => "mana-5-yellow",
    # asics
    "Gel Tarther" => "tarther-1",
    "Gel Tarther (2)" => "tarther-2",
    "GT-2140" => "asics-gt2140",
    # brooks
    "Mach 11 Spikeless" => "mach11",
    # new balance
    "M730" => "nb730",
    "MR890" => "nb890",
    "MR890V2 (grey/green)" => "nb890v2-green",
    "MR890V2 (grey/blue)" => "nb890v2-blue",
    # nike
    "Free Run 3.0 v2" => "free-3.0",
    "Lunar Montreal (grey)" => "lunar-montreal-grey",
    "Lunar Montreal (black)" => "lunar-montreal-black",
    "Zoom Streak 3" => "streak3-1",
    "Zoom Streak 3 (2)" => "streak3-2",
    "Zoom Streak XC 2" => "streak-xc2",
    # saucony
    "ProGrid Guide 3" => "guide-3",
    "ProGrid Kinvara" => "kinvara",
);

my %distance_unit_map = (
    "Mile" => "miles",
    "Kilometer" => "km",
    "Meter" => "m",
);

my %weight_unit_map = (
);

my %temperature_unit_map = (
);

sub find_garmin_file {
    my $year = shift;
    my $month = shift;
    my $day = shift;
    my $hour = shift;
    my $min = shift;

    my $pattern = sprintf("%04d-%02d-%02d-%02d-%02d-*",
			  $year, $month, $day, $hour, $min);

    my @files = ();

    my $out = `/usr/bin/find $garmin_dir -name $pattern -print`;
    foreach (split('\n', $out)) {
	if (/.(fit|FIT|tcx|TCX)$/) {
	    push @files, $_;
	}
    }

    my $file_count = scalar @files;

    if ($file_count == 1) {
	return $files[0];
    } else {
	if ($file_count > 1) {
	    print STDOUT "warning multiple GPS files found for $pattern: @files\n";
	}
	return "";
    }
}

open INPUT, '<', $ra_log_file
    or die "can't open $ra_log_file";

# skip first line
$_ = <INPUT>;

while (<INPUT>) {
    chomp;
    my ($Date, $TimeOfDay, $Type, $SubType, $Distance, $DistanceUnit, $Duration, $Weight, $WeightUnit, $RestHR, $AvgHR, $MaxHR, $Sleep, $Calories, $Quality, $Effort, $Weather, $Temperature, $TempUnit, $Notes, $Course, $CourseSurface, $CourseNotes, $ShoeMake, $ShoeModel, $Size, $System, $ShoeSerial, $ShoePrice, $OverallPlace, $FieldSize, $GroupMinAge, $GroupMaxAge, $GroupPlace, $GroupSize, $GenderPlace, $GenderSize) = split("\t");

    if ($ignored_types{$Type}) {
	next;
    }

    my ($year, $month, $day, $hour, $minute);
    if ($TimeOfDay) {
	my $date_time = "$Date $TimeOfDay";
	if ($date_time =~ /(\d+)-(\d+)-(\d+) (\d+):(\d+)/) {
	    $year = $1; $month = $2; $day = $3; $hour = $4; $minute = $5;
	} else {
	    die "Weird date format: $date_time";
	}
    } else {
	if ($Date =~ /(\d+)-(\d+)-(\d+)/) {
	    $year = $1; $month = $2; $day = $3; $hour = 0; $minute = 0;
	} else {
	    die "Weird date format: $Date";
	}
    }

    my $output_file = sprintf("%04d/%02d/%02d-%02d%02d.txt",
			      $year, $month, $day, $hour, $minute);
    my $output_dir = dirname($output_file);

    if (!$opt_overwrite && -f "$activities_dir/$output_file") {
	next;
    }

    if (! -d "$activities_dir/$output_dir") {
	mkpath("$activities_dir/$output_dir")
	    or die "can't create output directory";
    }

    open OUTPUT, '>', "$activities_dir/$output_file"
	or die "can't create output file";

    if ($TimeOfDay) {
	print OUTPUT "Date: $Date $TimeOfDay\n";
    } else {
	print OUTPUT "Date: $Date\n";
    }

    my $gps_file = find_garmin_file($year, $month, $day, $hour, $minute);

    if ($gps_file) {
	my $file = basename($gps_file);
	print OUTPUT "GPS-File: $file\n";
    }

    $Type = lc($Type);
    print OUTPUT "Activity: $Type\n";

    if ($SubType) {
	my $subtype = $subtype_map{$SubType};
	if (!$subtype) {
	    $subtype = lc($SubType);
	}
	print OUTPUT "Type: $subtype\n";
    }

    if ($Course) {
	print OUTPUT "Course: $Course\n";
    }

    if ($Duration) {
	my $dur = $Duration;
	$dur =~ s/^0://;
	print OUTPUT "Duration: $dur\n";
    }

    if ($Distance) {
	my $distance = "$Distance";
	if ($DistanceUnit) {
	    my $unit = $distance_unit_map{$DistanceUnit};
	    if (!$unit) {
		$unit = lc($DistanceUnit);
	    }
	    $distance = "$distance $unit";
	}
	print OUTPUT "Distance: $distance\n";
    }

    if ($Weight) {
	my $weight = "$Weight";
	if ($WeightUnit) {
	    my $unit = $weight_unit_map{$WeightUnit};
	    if (!$unit) {
		$unit = lc($WeightUnit);
	    }
	    $weight = "$weight $unit";
	}
	print OUTPUT "Weight: $weight\n";
    }

    if ($RestHR) {
	print OUTPUT "Resting-HR: $RestHR\n";
    }
    if ($AvgHR) {
	print OUTPUT "Average-HR: $AvgHR\n";
    }
    if ($MaxHR) {
	print OUTPUT "Max-HR: $MaxHR\n";
    }

    if ($Calories) {
	print OUTPUT "Calories: $Calories\n";
    }

    if ($Quality) {
	print OUTPUT "Quality: $Quality\n";
    }
    if ($Effort) {
	print OUTPUT "Effort: $Effort\n";
    }

    if ($ShoeModel) {
	my $shoe = $ShoeModel;
	if ($ShoeSerial) {
	    $shoe = "$shoe ($ShoeSerial)";
	}
	if ($equipment_map{$shoe}) {
	    $shoe = $equipment_map{$shoe};
	}
	print OUTPUT "Equipment: $shoe\n";
    }

    if ($Temperature) {
	my $temperature = "$Temperature";
	if ($TempUnit) {
	    my $unit = $temperature_unit_map{$TempUnit};
	    if (!$unit) {
		$unit = $TempUnit;
	    }
	    $temperature = "$temperature $unit";
	}
	print OUTPUT "Temperature: $temperature\n";
    }

    if ($Weather) {
	my $weather = lc($Weather);
	$weather =~ s/,/ /g;
	$weather =~ s/partlycloudy/partly-cloudy/g;
	print OUTPUT "Weather: $weather\n";
    }

    if ($OverallPlace) {
	print OUTPUT "Overall-Place: $OverallPlace\n";
    }
    if ($FieldSize) {
	print OUTPUT "Field-Size: $FieldSize\n";
    }
    if ($GroupPlace) {
	print OUTPUT "Group-Place: $GroupPlace\n";
    }
    if ($GroupSize) {
	print OUTPUT "Group-Size: $GroupSize\n";
    }
    if ($GroupMinAge) {
	print OUTPUT "Group-Min-Age: $GroupMinAge\n";
    }
    if ($GroupMaxAge) {
	print OUTPUT "Group-Max-Age: $GroupMaxAge\n";
    }
    if ($GenderPlace) {
	print OUTPUT "Gender-Place: $GenderPlace\n";
    }
    if ($GenderSize) {
	print OUTPUT "Gender-Size: $GenderSize\n";
    }

    if ($Notes) {
	print OUTPUT "\n";
	my $notes = $Notes;
	$notes =~ s/<br>/\n/g;
	$notes =~ s/— /-- /g;
	$notes =~ s/—/--/g;
	$notes =~ s/…/.../g;
	$notes = wrap("", "", $notes);
	print OUTPUT "$notes\n";
    }

    close OUTPUT;

    print STDOUT "Created $output_file\n";
}

close INPUT;
