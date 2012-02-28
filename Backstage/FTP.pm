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
package Backstage::FTP;

use strict;
use warnings;

use Net::FTP;
use File::Basename;
use Carp;

sub new {
    my $class = shift;
    my $prefs = shift;
    my $self->{'prefs'} = $prefs->ftp;
    bless($self, $class);
    return $self;
}

sub upload {
    my $self = shift;
    my $file = shift;
    my @stat = stat($file);

    if (scalar @stat) {
        my $ftp = Net::FTP->new($self->{'prefs'}->host)
            or croak("Failed to connect to " . $self->{'prefs'}->host);
        $ftp->login($self->{'prefs'}->username, $self->{'prefs'}->password)
            or croak($ftp->message);
        $ftp->binary or croak $ftp->message;
        $ftp->cwd($self->{'prefs'}->upload_dir) or croak $ftp->message;
        $ftp->put($file, basename($file)) or croak $ftp->message;
        $ftp->quit();
        return basename($file);
    } else {
        croak("$file does not exist");
    }

    return undef;
}

1;
