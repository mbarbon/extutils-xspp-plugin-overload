#!/usr/bin/perl

use strict;

use Module::Build;

my $build = Module::Build->new
  ( module_name => 'ExtUtils::XSpp::Plugin::Overload',
    license     => 'perl',
    requires    =>
      { 'perl'           => '5.8.3',
        'ExtUtils::XSpp' => '0.18',
        },
    build_requires =>
      { 'Test::Base'          => '0',
        'Test::Differences'   => '0',
        },
    share_dir   => 'cpp',
    );
$build->create_build_script;
