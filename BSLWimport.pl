#!/usr/bin/perl
# ---------------------------------------------------------------
# Copyright © 2012 Merrimack Valley Library Consortium
# Jason Stephenson <jstephenson@mvlc.org>

# This program is free software; you can redistribute it and/or modify
# it under the terms of the Lesser GNU General Public License as
# published by the Free Software Foundation; either version 3 of the
# License, or (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# ---------------------------------------------------------------

use strict;
use warnings;

use JSONPrefs;
use Backstage::FTP;
use Backstage::Import;
use Archive::Zip qw( :ERROR_CODES :CONSTANTS );
use File::Basename;
use Carp;

# pass input file names on the command line as arguments
my @input_files = ();

my $prefs_file = $ENV{'HOME'} . "/myprefs.d/bslw.json";

# Loop through the command line arguments:
foreach my $arg (@ARGV) {
    if ($arg =~ /\.json$/) {
        $prefs_file = $arg;
    } else {
        push(@input_files, $arg);
    }
}

my $prefs = JSONPrefs->load($prefs_file);

# Download files from the ftp server if we have not input files as
# arguments.
unless (scalar @input_files) {
    my $ftp = Backstage::FTP->new($prefs);
    @input_files = $ftp->download;
}

# Get our working directory:
my $cwd = $prefs->get('import')->working_dir;
$cwd .= "/" unless ($cwd =~ /\/$/);

# Create an import object.
my $import = Backstage::Import->new($prefs);

foreach my $file (@input_files) {
    # Skip the reports archive.  Maybe someone will want them emailed
    # to them in the future.
    next if ($file =~ /\.reports\./);

    # Probably need to unzip the curcat data.
    my $zip = Archive::Zip->new();
    unless ($zip->read($file) == AZ_OK) {
        carp "Failed to read $file";
    }

    my $member;
    foreach $member ($zip->membersMatching('\.BIB\.')) {
        my $bibfile = $cwd . basename($member->fileName());
        if ($member->extractToFileNamed($bibfile) == AZ_OK) {
            $import->doFile($bibfile);
            cleanup($bibfile) if ($prefs->get('import')->cleanup =~ /^true$/i);
        } else {
            carp "Failed to extract " . $member->fileName() . " to $bibfile";
        }
    }

    # Handle authority deletes:
    my $authfile;
    foreach $member ($zip->membersMatching('\.DEL\.')) {
        $authfile = $cwd . basename($member->fileName());
        if ($member->extractToFileNamed($authfile) == AZ_OK) {
            $import->doFile($authfile);
            cleanup($authfile) if ($prefs->get('import')->cleanup =~ /^true$/i);
        } else {
            carp "Failed to extract " . $member->fileName() . " to $authfile";
        }
    }

    # Handle other authorities
    foreach $member ($zip->membersMatching('^(?!.*\.(BIB|DEL)\.)')) {
        $authfile = $cwd . basename($member->fileName());
        if ($member->extractToFileNamed($authfile) == AZ_OK) {
            $import->doFile($authfile);
            cleanup($authfile) if ($prefs->get('import')->cleanup =~ /^true$/i);
        } else {
            carp "Failed to extract " . $member->fileName() . " to $authfile";
        }
    }
}

sub cleanup {
    # Made this a sub in case we ever want to do more than just unlink
    # the file.
    my $file = shift;
    return unlink($file);
}
