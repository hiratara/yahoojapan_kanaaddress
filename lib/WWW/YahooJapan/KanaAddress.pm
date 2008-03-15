package WWW::YahooJapan::KanaAddress;

require 5.006;

use warnings;
use strict;
use Carp;

use version; our $VERSION = qv('0.1.0');

use LWP::UserAgent;
use URI::Escape;

my %_tdfk_dict = qw/
�̳�ƻ �ۤä����ɤ�
�Ŀ��� ������ꤱ��
��긩 ����Ƥ���
�ܾ븩 �ߤ䤮����
���ĸ� ����������
������ ��ޤ�������
ʡ�縩 �դ����ޤ���
��븩 ���Ф餭����
���ڸ� �Ȥ�������
���ϸ� ����ޤ���
��̸� �������ޤ���
���ո� ���Ф���
����� �Ȥ����礦��
����� ���ʤ��櫓��
�ٻ��� �Ȥ�ޤ���
���㸩 �ˤ���������
��� �������櫓��
ʡ�温 �դ�������
������ ��ޤʤ�����
Ĺ� �ʤ��Τ���
���츩 ���դ���
�Ų��� ������������
���θ� ����������
���Ÿ� �ߤ�����
���츩 ��������
������ ���礦�Ȥ�
����� ����������
ʼ�˸� �Ҥ礦������
���ɸ� �ʤ餱��
�²λ��� �狼��ޤ���
Ļ�踩 �ȤäȤꤱ��
�纬�� ���ޤͤ���
������ ������ޤ���
���縩 �Ҥ��ޤ���
������ ��ޤ�������
���縩 �Ȥ����ޤ���
��� �����櫓��
��ɲ�� ���Ҥᤱ��
���θ� ����������
ʡ���� �դ���������
���츩 ��������
Ĺ�긩 �ʤ���������
���ܸ� ���ޤ�Ȥ���
��ʬ�� ������������
�ܺ긩 �ߤ䤶������
�����縩 �������ޤ���
���츩 �����ʤ櫓��
/;

my $search_url_tpl = 'http://search.map.yahoo.co.jp/search?p=%s&ei=euc-jp';
my $kana_url_tpl   = 'http://map.yahoo.co.jp/address?ac=%s';


# ���󥹥ȥ饯��
sub new{ 
	my $class = shift;

	my %opt = ref($_[0]) ? %{$_[0]} : @_;

	my $ua = $opt{ua} || LWP::UserAgent->new();

	bless {ua => $ua}, $class;
};


# ����: �����������
# ����: HTML
# ����: �����������ʸ����
sub _strip_tag{
	my $self = shift;
	my @strs = @_;
	return map { my $s = $_; $s =~ s/<[^>]+>//g; $s; } @strs;
}


# ����: Yahoo Maps�ˤơ���ͳʸ������Ԥ�
# ����: ������
# ����: ��̥ڡ�����HTML(̵�ù�)
sub _do_freeword_search{
	my $self = shift;
	my $word = shift;

	my $url = sprintf($search_url_tpl, uri_escape($word));

	my $ua  = $self->{ua};
	my $res = $ua->get($url);
	return $res->content();
}


# ����: Į��ʸ�����Yahoo�ǰ���Į��ʸ������Ѵ�
# ����: ��ƻ�ܸ�, (Yahoo�񼰤�)�Զ�ʸ����, Į��ʸ����
# ����: (Yahoo�񼰤�)Į��ʸ����
sub _correct_choaza{
	my $self = shift;
	my ($tdfk, $corrected_shiku, $choaza) = @_;

	my $html = $self->_do_freeword_search($tdfk . $corrected_shiku . $choaza);

	# ������̤ΰ��ֺǽ����
	my $corrected_address = undef;
	if ($html =~ 
	       m{<a [^>]+http://map\.yahoo\.co\.jp/pl\?p=[^>]+>(.+?)</a>}) {
		$corrected_address = $1;
	}else{
		die "can't find $corrected_shiku, $choaza .";
	}

	# �Զ���ʬ�����
	my $regex = quotemeta($tdfk. $corrected_shiku);
	$corrected_address =~ s/^$regex//;

	# ���Ϥ�ʤ�
	$corrected_address =~ s/[0-9]+$//;

	# ���ܰʹߤ����
	$corrected_address =~ s/[0-9]+����$//;

	return $corrected_address;
}


# ����: �Զ�ʸ�����Yahoo�ǰ����Զ�ʸ������Ѵ�
# ����: ��ƻ�ܸ�ʸ����, �Զ�ʸ����
# ����: �Զ�ID, (Yahoo�񼰤�)�Զ�ʸ����
sub _correct_shiku{
	my $self = shift;
	my ($tdfk, $shiku) = @_;

	my $html = $self->_do_freeword_search($tdfk . $shiku);

	my @codes = ();
	while ($html =~ 
	       m{<a [^>]+map\.yahoo\.co\.jp/address\?ac=(\d+)[^>]+>(.+?)</a>}g) {
		push(@codes, [$1, $2]);
	}
	die "can't determine codes: " . join(',', @codes) if(@codes != 1);

	my ($code, $corrected_shiku) = @{ $codes[0] };

	# ��ƻ�ܸ�����ʬ�����
	my $regexp = quotemeta($tdfk);
	$corrected_shiku =~ s/^$regexp//;

	return ($code, $corrected_shiku);
}


# ����: �Զ���б�����եꥬ�ʤΰ���������
# ����: �Զ�ID
# ����: �ϥå����ե���� {����1 => ����1, ����2 => ����2, ...}
sub _get_kana_dict{
	my $self = shift;
	my $shiku_code = shift;
	my $url = sprintf($kana_url_tpl, $shiku_code);

	my $ua  = $self->{ua};
	my $res = $ua->get($url);
	my $c = $res->content();
	my %ret = ();
	while ($c =~ m{<dd><div class="ruby">(.+?)</div>(.+?)</dd>}g) {
		my ($kana, $kanji) = $self->_strip_tag($1, $2);
		$ret{$kanji} = $kana;
	}
	return \%ret;
}


# ����: ��̾���Զ衢Į�����Ф��뤫�ʤ��֤�
# ����: ��̾���Զ衢Į��
# ����: ����ᤤ�����������礦����
sub search{
	my $self = shift;
	my ($tdfk, $shiku, $choaza) = @_;

	# ��̾�����뤿��˻Զ�ID��ɬ�ס������Ѥ�Yahooɽ���λԶ�������롣
	my ($shiku_code, $corrected_shiku) = $self->_correct_shiku($tdfk, $shiku);
	my $tdfk_code = substr($shiku_code, 0, 2);

	my $ref_choaza = $self->_get_kana_dict($shiku_code);
	my $ref_shiku  = $self->_get_kana_dict($tdfk_code);

	# �Զ�
	my $shiku_kana = $ref_shiku->{$corrected_shiku};

	# Į��
	my $corrected_choaza = '';
	my $choaza_kana = '';
	if(exists $ref_choaza->{$choaza}){
	    # �Ѵ������˸��Ĥ��ä�
	    $choaza_kana = $ref_choaza->{$choaza};
	}else{
	    # Yahooɽ�����Ѵ������ƥ�����
	    $corrected_choaza = $self->_correct_choaza(
	                           $tdfk, $corrected_shiku, $choaza);
	    $choaza_kana = $ref_choaza->{$corrected_choaza} 
	                             if exists $ref_choaza->{$corrected_choaza};
	}

	die sprintf("can't read: input(%s, %s), search(%s, %s)", 
	            $shiku, $choaza, $corrected_shiku, $corrected_choaza)
	            if ! $shiku_kana or ! $choaza_kana;

	return $_tdfk_dict{$tdfk}, $shiku_kana,$choaza_kana;
}




1; # Magic true value required at end of module
__END__

=encoding euc-jp

=head1 NAME

WWW::YahooJapan::KanaAddress - translating the address in Japan into kana.

=head1 SYNOPSIS

    use WWW::YahooJapan::KanaAddress;

    my $yahoo = WWW::YahooJapan::KanaAddress->new();
    print $yahoo->search('������', '����Į', 'Ļ��'), "\n";

results:

    ��ޤʤ����󤫤���������礦�Ȥ�

=head1 DESCRIPTION

This class translates the address written in Kanji into Kana by using Yahoo! Japan Maps.

=head2 Methods

=over

=item my $yahoo = WWW::YahooJapan::KanaAddress->new( ua => 'your LWP::UserAgent');

a constructor. You can set a LWP::UserAgent object if you want.

=item my ($kana_ken, $kana_shiku, $kana_choaza) = $yahoo->search($ken, $shiku, $choaza);

search kana by Yahoo!Japan Maps. The arguments and return values must be encoded to euc-jp. You can't use unicode string.

=over 2

=item $ken

Prefecture in Japan, should be ended with '��' or 'ƻ' or '��' or '��'.

=item $shiku

Name of city and district, should be ended with '��' or '��' or 'Į' or '¼'.

=item $choaza

The rest of the string of address. It might contain 'Į' and '��'.

=back

You can use a vague address to some degree. For example: 

    print $yahoo->search('��븩', 'ζ�����', '��Į'), "\n";
    print $yahoo->search('��븩', 'ζ���', '��Į'), "\n";
    print $yahoo->search('��븩', 'ε�����', '��Į'), "\n";

These sentences output the same result. This is a function of Yahoo!Japan Maps.

=back

=head1 CONFIGURATION AND ENVIRONMENT

WWW::YahooJapan::KanaAddress requires no configuration files or environment variables.


=head1 DEPENDENCIES

LWP::UserAgent, and Yahoo!Japan :-p


=head1 INCOMPATIBILITIES

None reported.


=head1 BUGS AND LIMITATIONS

No bugs have been reported.

Please report any bugs or feature requests to
C<hiratara@cpan.org>, or through the web interface at L<http://rt.cpan.org>.


=head1 AUTHOR

Masahiro Honma  C<< <hiratara@cpan.org> >>


=head1 LICENCE AND COPYRIGHT

Copyright (c) 2008, Masahiro Honma C<< <hiratara@cpan.org> >>. All rights reserved.

This module is free software; you can redistribute it and/or
modify it under the same terms as Perl itself. See L<perlartistic>.


=head1 DISCLAIMER OF WARRANTY

BECAUSE THIS SOFTWARE IS LICENSED FREE OF CHARGE, THERE IS NO WARRANTY
FOR THE SOFTWARE, TO THE EXTENT PERMITTED BY APPLICABLE LAW. EXCEPT WHEN
OTHERWISE STATED IN WRITING THE COPYRIGHT HOLDERS AND/OR OTHER PARTIES
PROVIDE THE SOFTWARE "AS IS" WITHOUT WARRANTY OF ANY KIND, EITHER
EXPRESSED OR IMPLIED, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE. THE
ENTIRE RISK AS TO THE QUALITY AND PERFORMANCE OF THE SOFTWARE IS WITH
YOU. SHOULD THE SOFTWARE PROVE DEFECTIVE, YOU ASSUME THE COST OF ALL
NECESSARY SERVICING, REPAIR, OR CORRECTION.

IN NO EVENT UNLESS REQUIRED BY APPLICABLE LAW OR AGREED TO IN WRITING
WILL ANY COPYRIGHT HOLDER, OR ANY OTHER PARTY WHO MAY MODIFY AND/OR
REDISTRIBUTE THE SOFTWARE AS PERMITTED BY THE ABOVE LICENCE, BE
LIABLE TO YOU FOR DAMAGES, INCLUDING ANY GENERAL, SPECIAL, INCIDENTAL,
OR CONSEQUENTIAL DAMAGES ARISING OUT OF THE USE OR INABILITY TO USE
THE SOFTWARE (INCLUDING BUT NOT LIMITED TO LOSS OF DATA OR DATA BEING
RENDERED INACCURATE OR LOSSES SUSTAINED BY YOU OR THIRD PARTIES OR A
FAILURE OF THE SOFTWARE TO OPERATE WITH ANY OTHER SOFTWARE), EVEN IF
SUCH HOLDER OR OTHER PARTY HAS BEEN ADVISED OF THE POSSIBILITY OF
SUCH DAMAGES.
