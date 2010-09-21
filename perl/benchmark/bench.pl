###
### $Release$
### $Copyright$
###

## packages
push @INC, '../lib';
#use strict;
use strict qw(vars subs);   # to avoid compile error on '&$var()'


## helper function
sub read_file {
    my ($filename) = @_;
    #Tenjin::Util::write_file($filename, $content);
    open my $fh, $filename  or die "$filename: $!";
    read $fh, my $content, (-s $filename);
    close $fh;
    return $content;
}

sub write_file {
    my ($filename, $content) = @_;
    #Tenjin::Util::write_file($filename, $content);   # or File::Slurp
    $filename =~ /\A\w[-\w.]*\Z/  or die "$filename: invalid file name.";
    $filename = $&;   # avoid error on taint mode
    open my $fh, ">$filename"  or die "$filename: $!";
    print $fh $content;
    close $fh;
}

sub _touch {
    my ($src, $dst) = @_;
    my $mtime = (stat $src)[9];
    utime $mtime, $mtime, $dst;
}


##
## base class of benchmark
##
package BenchmarkObject;

our @subclasses;
our $flag_escape = undef;

sub new {
    my ($class) = @_;
    my $this = {
        name => undef,
    };
    return bless $this, $class;
}

sub before_all {
    return 0;
}

sub before_each {
    return 0;
}

sub after_each {
    return 0;
}

sub after_all {
    return 0;
}

sub load_package {
    my ($this, $package_name) = @_;
    $@ = undef;
    eval "use $package_name";
    my $errmsg = $@;
    return unless $errmsg;
    #warn "*** failed to load package '$package_name': $@";
    warn "*** failed to load package '$package_name': skipped.\n";
    $@ = undef;
    return $errmsg;
}

sub build_template {
    my ($class, $filename) = @_;
    my $body   = main::read_file("templates/$filename")    or die $!;
    my $header = main::read_file("templates/_header.html") or die $!;
    my $footer = main::read_file("templates/_footer.html") or die $!;
    $body = $class->escape_template($body) if $flag_escape;
    main::write_file($filename, $header . $body . $footer);
}

sub escape_template {
    my ($class, $content) = @_;
    return $content;
}


##
## Tenjin benchmark
##
package TenjinBenchmark;
our @ISA = ('BenchmarkObject');
push @BenchmarkObject::subclasses, 'TenjinBenchmark';
our $template_filename = 'bench_tenjin.plhtml';

sub before_all {
    my ($class) = @_;
    $class->build_template($template_filename);
    $class->load_package('Tenjin')  and return -1;
}

sub escape_template {
    my ($class, $s) = @_;
    $s =~ s/\[==/[=/g;
    return $s;
}

sub before_each {
    my ($this) = @_;
    my $cache = $template_filename.".cache";
    unlink $cache if -f $cache;
    if ($this->{name} eq 'tenjin_safe') {
        my $old = main::read_file($template_filename);
        my $new = $old;
        $new =~ s/\[==(.*?)=]/[=safe_str(\1)=]/g;
        #$old ne $new  or die "*** failed to convert template.";
        main::write_file($template_filename, $new);
    }
}

sub after_each {
    my ($this) = @_;
    if ($this->{name} eq 'tenjin_safe') {
        my $old = main::read_file($template_filename);
        my $new = $old;
        $new =~ s/\[=safe_str\((.*?)\)=]/[==\1=]/g;
        #$old ne $new  or die "*** failed to convert template.";
        main::write_file($template_filename, $new);
    }
}

sub _bench_tenjin_template {
    my ($this, $n, $context) = @_;
    my $output;
    while ($n--) {
        my $template = Tenjin::Template->new($template_filename);
        $output = $template->render($context);
    }
    return $output;
}

sub _bench_tenjin_template_cache {
    my ($this, $n, $context) = @_;
    my $output;
    my $template = Tenjin::Template->new($template_filename);
    my $script = $template->{script};
    my $cache_filename = $template_filename . '.cache';
    main::write_file($cache_filename, $script);
    while ($n--) {
        my $template = Tenjin::Template->new();
        $template->{script} = main::read_file($cache_filename);
        $output = $template->render($context);
    }
    return $output;
}

sub _bench_tenjin_template_reuse {
    my ($this, $n, $context) = @_;
    my $output;
    my $template = Tenjin::Template->new($template_filename);
    while ($n--) {
        $output = $template->render($context);
    }
    return $output;
}

sub _bench_tenjin_template_convert {
    my ($this, $n, $context) = @_;
    my $output;
    my $template = Tenjin::Template->new();
    my $input = main::read_file($template_filename);
    while ($n--) {
        $output = $template->convert($input);
    }
    return $output;
}

## tenjin::template (compile)
sub _bench_tenjin_template_compile {
    my ($this, $n, $context) = @_;
    my $output;
    my $template = Tenjin::Template->new($template_filename);
    my $f = $template->compile();
    #main::write_file('tenjin_defun.pl', $script);
    while ($n--) {
        $output = $template->render($context);
    }
    return $output;
}

## tenjin (render)
sub bench_tenjin {
    my ($this, $n, $context) = @_;
    my $output;
    my $engine = Tenjin::Engine->new();
    while ($n--) {
        $output = $engine->render($template_filename, $context);
    }
    return $output;
}

## tenjin (create+render)
sub bench_tenjin_create {
    my ($this, $n, $context) = @_;
    my $output;
    while ($n--) {
        my $engine = Tenjin::Engine->new();
        $output = $engine->render($template_filename, $context);
    }
    return $output;
}

## tenjin (create without cache)
sub bench_tenjin_nocache {
    my ($this, $n, $context) = @_;
    my $output;
    while ($n--) {
        my $engine = Tenjin::Engine->new({cache=>0});
        $output = $engine->render($template_filename, $context);
    }
    return $output;
}

## tenjin (render + SafeEngine)
sub bench_tenjin_safe {
    my ($this, $n, $context) = @_;
    my $output;
    my $engine = Tenjin::SafeEngine->new();
    while ($n--) {
        $output = $engine->render($template_filename, $context);
    }
    return $output;
}

## tenjin (with Webext module)
sub bench_tenjin_webext {
    $@ = undef;
    eval {
        #use Webext;
        require Webext;
        import Webext;
    };
    if ($@) {
        print "(Webext is not installed.)\n";
        $@ = undef;
        return -1;
    }
    my ($this, $n, $context) = @_;
    my $output;
    my $engine = Tenjin::Engine->new({cache=>0, escapefunc=>'Webext::escape_html'});
    while ($n--) {
        $output = $engine->render($template_filename, $context);
    }
    return $output;
}

## tenjin (defun)
sub _bench_tenjin_defun {
    my ($this, $n, $context) = @_;
    my $output;
    my $template = Tenjin::Template->new($template_filename, {escapefunc=>'Tenjin::Util::escape_xml'});
    my $script = $template->defun('render_tenjin_template', qw[list]);
    #main::write_file('tenjin_defun.pl', $script);
    eval $script;
    $@ and die($@);
    while ($n--) {
        $output = render_tenjin_template($context);
    }
    return $output;
}

## tenjin (eval)
sub _bench_tenjin_eval {
    my ($this, $n, $context) = @_;
    my $output;
    my $script;
    if (-f "bench_tenjin.plhtml.cache") {
        $script = main::read_file("bench_tenjin.plhtml.cache");
    } else {
        my $template = new Tenjin::Template($template_filename, {escapefunc=>'Tenjin::Util::escape_xml'});
        $script = $template->{script};
    }
    my $preamble = <<'END';
        my $_context = shift;
        my @_a = ();
        for (keys %$_context) { push @_a, "my \$$_=\$_context->{$_};"; }
        #eval join("", @_a);
END
    #my $clos = eval "sub { $preamble $script }";  ! $@ or die $@;
    eval "sub _tmpfunc111 { $preamble $script }";  ! $@ or die $@;
    while ($n--) {
        #$output = $clos->($context);
        my $list = $context->{'list'};
        $output = _tmpfunc111($context);
    }
    return $output;
}


##
## Template-Toolkit benchmark
##
package TemplateToolkitBenchmark;
our @ISA = ('BenchmarkObject');
push @BenchmarkObject::subclasses, 'TemplateToolkitBenchmark';
our $template_filename = 'bench_tt.tt';

sub before_all {
    my ($this) = @_;
    $this->build_template($template_filename);
    $this->load_package('Template')  and return -1;
}

sub escape_template {
    my ($class, $s) = @_;
    $s =~ s/\[%\s*([^A-Z ].*?)\s*%\]/[% $1 | html %]/g;
    return $s;
}

## Template-Toolkit (render)
sub bench_tt {
    my ($this, $n, $context) = @_;
    my $output;
    my $template = Template->new();
    while ($n--) {
        $output = undef;  # required
        $template->process($template_filename, $context, \$output);
    }
    return $output;
}

## Template-Toolkit (create+render)
sub bench_tt_create {
    my ($this, $n, $context) = @_;
    my $output;
    while ($n--) {
        my $template = Template->new();
        $output = undef;  # required
        $template->process($template_filename, $context, \$output);
    }
    return $output;
}


##
## HTML::Template benchmark
##
package HtmlTemplateBenchmark;
our @ISA = ('BenchmarkObject');
push @BenchmarkObject::subclasses, 'HtmlTemplateBenchmark';
our $template_filename = "bench_htmltmpl.tmpl";

sub before_all {
    my ($this) = @_;
    $this->build_template($template_filename);
    $this->load_package("HTML::Template")  and return -1;
}

sub escape_template {
    my ($class, $s) = @_;
    $s =~ s/<TMPL_VAR (.*?)>/<TMPL_VAR $1 ESCAPE=HTML>/g;
    return $s;
}

sub _convert_context {
    my ($this, $context) = @_;
    my $i = 0;
    my @list = map {
        my %item = %$_;
        delete $item{name2};
        $item{n} = ++$i;
        $item{class} = $i % 2 == 0 ? 'even' : 'odd';
        $item{minus} = $item{change} < 0.0;
        \%item;
    } @{$context->{list}};
    return { list=>\@list };
}

## HTML::Template (render)
sub bench_htmltmpl {
    my ($this, $n, $context) = @_;
    $context = $this->_convert_context($context);
    my $output;
    my $template = new HTML::Template(filename=>$template_filename);
    while ($n--) {
        $template->param($context);
        $output = $template->output;
    }
    return $output;
}

## HTML::Template (create+render)
sub bench_htmltmpl_create {
    my ($this, $n, $context) = @_;
    $context = $this->_convert_context($context);
    my $output;
    while ($n--) {
        my $template = new HTML::Template(filename=>$template_filename);
        $template->param($context);
        $output = $template->output;
    }
    return $output;
}

## HTML::Template (render with editing context data each time)
sub bench_htmltmpl_edit_context {
    my ($this, $n, $context) = @_;
    $context = $this->_convert_context($context);
    my $output;
    my $template = new HTML::Template(filename=>$template_filename);
    while ($n--) {
        #
        my $i = 0;
        for my $item (@{$context->{list}}) {
            delete $item->{name2};
            $item->{n} = ++$i;
            $item->{class} = $i % 2 == 0 ? 'even' : 'odd';
            $item->{minus} = $item->{change} < 0.0;
        }
        #
        $template->param($context);
        $output = $template->output;
    }
    return $output;
}


##
## MobaSiF::Template benchmark
##
package MobaSiFTemplateBenchmark;
our @ISA = ('BenchmarkObject');
push @BenchmarkObject::subclasses, 'MobaSiFTemplateBenchmark';
our $template_filename = "bench_mobasif.html";
our $compiled_filename = "bench_mobasif.bin";

sub before_all {
    my ($this) = @_;
    $this->build_template($template_filename);
    $this->load_package("MobaSiF::Template")  and return -1;
    $this->load_package("MobaSiF::Template::Compiler")  and return -1;
    MobaSiF::Template::Compiler::compile($template_filename, $compiled_filename);
}

sub escape_template {
    my ($class, $s) = @_;
    $s =~ s/\$=b:(.*?)\$/\$=h:$1\$/g;
    return $s;
}

## MobaSiF::Template (render)
sub bench_mobasif {
    my ($this, $n, $context) = @_;
    my $output;
    #
    my $i = 0;
    my @list = map {
        my %item = %$_;
        $item{n} = ++$i;
        $item{class} = $i % 2 == 0 ? 'even' : 'odd';
        $item{minus} = $item{change} < 0.0;
        \%item;
    } @{$context->{list}};
    #
    while ($n--) {
        $output = MobaSiF::Template::insert($compiled_filename, {list=>\@list});
    }
    return $output;
}

## MobaSiF::Template (render with editing context each time)
sub bench_mobasif_edit_context {
    my ($this, $n, $context) = @_;
    my $output;
    my @list = map { my %item = %$_; \%item } @{$context->{list}};
    while ($n--) {
        #
        my $i = 0;
        for my $item (@list) {
            delete $item->{name2};
            $item->{n} = ++$i;
            $item->{class} = $i % 2 == 0 ? 'even' : 'odd';
            $item->{minus} = $item->{change} < 0.0;
        }
        #
        $output = MobaSiF::Template::insert($compiled_filename, {list=>\@list});
    }
    #print Dumper(\@list);            # changed
    #print Dumper($context->{list});  # not changed
    return $output;
}

## MobaSiF::Template (render with copying context each time)
sub bench_mobasif_copy_context {
    my ($this, $n, $context) = @_;
    my $output;
    while ($n--) {
        #
        my $i = 0;
        my @list = map {
            my %item = %$_;
            $item{n} = ++$i;
            $item{class} = $i % 2 == 0 ? 'even' : 'odd';
            $item{minus} = $item{change} < 0.0;
            \%item;
        } @{$context->{list}};
        #
        $output = MobaSiF::Template::insert($compiled_filename, {list=>\@list});
    }
    return $output;
}


##
## Text::MicroTemplate benchmark
##
package TextMicroTemplateBenchmark;
our @ISA = ('BenchmarkObject');
push @BenchmarkObject::subclasses, 'TextMicroTemplateBenchmark';
our $template_filename = "bench_microtmpl.mt";

sub before_all {
    my ($class) = @_;
    $class->build_template($template_filename);
    my $s = main::read_file($template_filename);
    $s =~ s/<\?(xml .*?)\?>/<<?= '' ?>?$1?<?= '' ?>>/;
    main::write_file($template_filename, $s);
    $class->load_package("Text::MicroTemplate qw(encoded_string)")  and return -1;
    $class->load_package("Text::MicroTemplate::File")  and return -1;
}

sub escape_template {
    my ($class, $s) = @_;
    #$s =~ s/<\?=\s*(.*?)\s*\?>/<? encoded_string($1) ?>/g;
    return $s;
}

## Text::MicroTemplate (render)
sub bench_microtmpl {
    my ($this, $n, $context) = @_;
    my $output;
    my $mt = Text::MicroTemplate::File->new(use_cache => 1);
    while ($n--) {
        $output = $mt->render_file($template_filename, $context);
    }
    return $output;
}

## Text::MicroTemplate (create+render)
sub bench_microtmpl_create {
    my ($this, $n, $context) = @_;
    my $output;
    while ($n--) {
        my $mt = Text::MicroTemplate::File->new(use_cache => 1);
        $output = $mt->render_file($template_filename, $context);
    }
    return $output;
}

sub _bench_microtmpl_nocache {
    my ($this, $n, $context) = @_;
    my $output;
    while ($n--) {
        my $mt = Text::MicroTemplate::File->new(use_cache => 0);
        $output = $mt->render_file($template_filename, $context);
    }
    return $output;
}



##
## Perl benchmark
##
package PerlBenchmark;
our @ISA = ('BenchmarkObject');
push @BenchmarkObject::subclasses, 'PerlBenchmark';
our $mode = $ENV{'MODE'} || 'func';
#use strict;

sub _invoke_benchmark {
    my ($name, $n, $_context) = @_;
    my $s = main::read_file("perlcode/$name.pl");
    my $ret;
    if ($mode eq 'func') {
        my $func = "render_$name";
        eval "sub $func { my (\$_context) = \@_; $s }";
        ! $@  or die $@;
        while ($n--) { $ret = &$func($_context); }  # error when 'strict ref' is enabled
    }
    elsif ($mode eq 'closure') {
        my $closure = eval "sub { my (\$_context) = \@_; $s }";
        while ($n--) { $ret = $closure->($_context); }
    }
    elsif ($mode eq 'eval') {
        while ($n--) { $ret = eval $s; }
    }
    my $output = ref($ret) eq 'ARRAY' ? join("", @$ret) : $ret;
    return $output;
}

sub _bench_perl_push {
    my ($this, $n, $_context) = @_;
    return _invoke_benchmark("perl_push", $n, $_context);
}

sub _bench_perl_pushjoin {
    my ($this, $n, $_context) = @_;
    return _invoke_benchmark("perl_pushjoin", $n, $_context);
}

sub _bench_perl_push3 {
    my ($this, $n, $_context) = @_;
    return _invoke_benchmark("perl_push3", $n, $_context);
}

sub _bench_perl_pushjoin3 {
    my ($this, $n, $_context) = @_;
    return _invoke_benchmark("perl_pushjoin3", $n, $_context);
}

sub _bench_perl_concat {
    my ($this, $n, $_context) = @_;
    return _invoke_benchmark("perl_concat", $n, $_context);
}

sub _bench_perl_concat2 {
    my ($this, $n, $_context) = @_;
    return _invoke_benchmark("perl_concat2", $n, $_context);
}

sub _bench_perl_concatpush {
    my ($this, $n, $_context) = @_;
    return _invoke_benchmark("perl_concatpush", $n, $_context);
}

sub _bench_perl_concatpushjoin {
    my ($this, $n, $_context) = @_;
    return _invoke_benchmark("perl_concatpushjoin", $n, $_context);
}

sub _bench_perl_escapehtml1 {
    my ($this, $n, $_context) = @_;
    return _invoke_benchmark("perl_escapehtml1", $n, $_context);
}

sub _bench_perl_escapehtml2 {
    my ($this, $n, $_context) = @_;
    return _invoke_benchmark("perl_escapehtml2", $n, $_context);
}

sub _bench_perl_escapehtml3 {
    my ($this, $n, $_context) = @_;
    return _invoke_benchmark("perl_escapehtml3", $n, $_context);
}

sub _bench_perl_escapehtml4 {
    my ($this, $n, $_context) = @_;
    return _invoke_benchmark("perl_escapehtml4", $n, $_context);
}

our %_ESCAPE_HTML = (
    '&'=>'&amp;', '<'=>'&lt;', '>'=>'&gt;', '"'=>'&quot;', "'"=>'&#039;',
);
our %_EH = %_ESCAPE_HTML;

sub escape_html {
    (my $s = $_[0]) =~ s/[&<>"]/$_EH{$&}/ge;
    $s;
}

sub escape_html2 {
    my $s = $_[0];
    $s =~ s/&/&amp;/g;
    $s =~ s/</&lt;/g;
    $s =~ s/>/&gt;/g;
    $s =~ s/"/&quot;/g;
    $s;
}


##
## main application
##
package BenchmarkApplication;
use strict;
use Data::Dumper;
use Getopt::Std;
use Time::HiRes;
use File::Basename;

sub new {
    my $class = shift;
    my $this = {
        ntimes      => 1000,
        flag_print  => undef,
        flag_all    => undef,
        flag_strict => undef,
        mode        => 'class',   # or 'hash'
    };
    return bless $this, $class;
}

sub parse_command_options {
    my ($this) = @_;
    my %opts;
    getopts('hvpeHwn:m:x:A', \%opts)  or die $@;
    $this->{ntimes}      = 0 + $opts{n}  if $opts{n};
    $this->{flag_print}  = 1             if $opts{p};
    $this->{flag_all}    = 1             if $opts{A};
    $this->{flag_strict} = 1             if $opts{w};
    $this->{flag_html}   = 1             if $opts{H};
    $BenchmarkObject::flag_escape = 1    if $opts{e};
    $this->{mode}        = $opts{m}      if $opts{m};
    ! $opts{m} || $opts{m} =~ /^(class|hash)$/  or
        die "-m $opts{m}: 'class' or 'hash' expected.\n";
    return \%opts;
}

sub help_message {
    my $script = basename(__FILE__);
    my $msg = <<END;
Usage: perl $script [..options..] [testname ...]
  -h              :  help
  -n N            :  repeat loop N times
  -e              :  escape html
  -p              :  print output
  -m [hash|class] :  mode
  -w              :  set Tenjin::USE_STRICT = 1
  -A              :  invoke all benchmarks (= public + private)
  -H              :  change context data to add '<B></B>'
END
    return $msg;
}

sub get_bench_classes {
    my ($this, $opt_all) = @_;
    my %dict;   # benchmark-name => class-name
    for my $klass (@BenchmarkObject::subclasses) {
        my %symbols = eval "%${klass}::";
        my $pat = $opt_all ? '^_?bench_' : '/^bench_';
        for (keys %symbols) {
            next unless s/$pat//;
            $dict{$_} = $klass;
        }
    }
    return %dict;
}

sub get_bench_names {
    my ($this, $flag_all) = @_;
    open FH, __FILE__  or die $!;
    my @lines = <FH>;
    close FH;
    my @names;
    my $pat = $flag_all ? '^ *sub _?bench_(\w+)' : '^ *sub bench_(\w+)';
    for (@lines) {
        push @names, $1 if /$pat/;
    }
    return @names;
}

sub load_context_data {
    my ($this) = @_;
    my $context_filename = 'bench_context.pl';
    #my $s = main::read_file($context_filename);
    #my $context = eval $s;   # error on taint mode
    my $context = require "./$context_filename";
    if ($this->{mode} eq 'hash') {
        $context->{list} = $context->{hash_list};
    }
    else {
        use User;
        my @arr = map { User->new($_) } @{$context->{hash_list}};
        $context->{list} = \@arr;
    }
    #$context->{list} = $this->{mode} eq 'hash' ? $context->{hash_list}
    #                                           : $context->{user_list};
    #print Dumper($context);
    if ($this->{flag_html}) {
        for (@{$context->{list}}) {
            $_->{name} = '<B>'.($_->{name}).'</B>';
        }
    }
    #use Data::Dumper;
    #print Dumper($context);
    return $context;
}

sub do_benchmark {
    my ($this, $name, $obj, $method, $context) = @_;
    printf("%-23s  ", $name);
    my $ntimes = $this->{ntimes};
    my @start_times = times();
    my $start_time  = Time::HiRes::time();
    my $output = $obj->$method($ntimes, $context);
    my @end_times   = times();
    my $end_time    = Time::HiRes::time();
    return $output if $output == -1;
    my $utime = $end_times[0] - $start_times[0];   # user
    my $stime = $end_times[1] - $start_times[1];   # sys
    my $rtime = $end_time - $start_time;           # real
    #printf("%-18s %10.4f  %10.4f  %10.4f  %10.4f\n",
    #    $testname, $utime, $stime, $utime + $stime, $rtime);
    printf("%10.4f  %10.4f  %10.4f  %10.4f\n",
           $utime, $stime, $utime + $stime, $rtime);
    return $output;
}

sub main {
    my ($this) = @_;
    ## parse command-line options
    my $opts = $this->parse_command_options();
    if ($opts->{h}) {
        print $this->help_message();
        return;
    }
    ## benchmark names to invoke
    my %bench_classes = $this->get_bench_classes('true');
    my @target_names;
    if (@ARGV) {
        my @all_bench_names   = $this->get_bench_names($this->{flag_all});
        for my $name (@ARGV) {
            if ($name =~ /\*/) {
                my $pat = '^'.$name.'$';
                $pat =~ s/\*/\.*/g;
                my @matched = grep { /$pat/ } @all_bench_names;
                @matched  or die "$name: unknown benchmark name.";
                push @target_names, @matched;
            }
            else {
                defined $bench_classes{$name}  or die "$name: unknown benchmark name.";
                push @target_names, $name;
            }
        }
    }
    else {
        @target_names = $this->get_bench_names($this->{flag_all});
    }
    if ($opts->{x}) {
        my $pat = join '|', split(',', $opts->{x});
        @target_names = grep { ! /^$pat$/ } @target_names;
    }
    ## context data
    my $context = $this->load_context_data();
    #print STDERR '*** debug: ', Dumper($context1);
    ## class names
    my @klasses;
    my %tmp;
    for (@target_names) {
        my $klass = $bench_classes{$_};
        next if defined $tmp{$klass};
        $tmp{$klass} = 1;
        push @klasses, $klass;
    }
    ## setup
    my %faileds;
    for my $klass (@klasses) {
        $faileds{$klass} = ($klass->before_all() == -1);
    }
    $Tenjin::USE_STRICT = 1 if $this->{flag_strict};
    ## do benchmark
    print "*** n = $this->{ntimes}\n";
    print "                               user         sys       total        real\n";
    $| = 1;
    my $output;
    for my $name (@target_names) {
        my $klass = $bench_classes{$name};
        next unless $klass;
        next if $faileds{$klass};
        my $obj = $klass->new();
        $obj->{name} = $name;
        my $method = "bench_$name";
        my %symbols = eval "%${klass}::";
        #$method = "_bench_$name" unless defined $symbols{$method};  # error on taint mode
        my $c = $symbols{$method};
        $method = "_bench_$name" unless ($c);
        if ($obj->before_each() != -1) {
            $output = $this->do_benchmark($name, $obj, $method, $context);
        }
        $obj->after_each();
        main::write_file("output.$name", $output) if $opts->{p};
    }
    ## teardown
    for my $klass (values %bench_classes) {
        $klass->after_all();
    }
}


##
## main package
##

package main;
my $app = BenchmarkApplication->new();
$app->main();
