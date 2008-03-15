package WWW::YahooJapan::KanaAddress;

require 5.006;

use warnings;
use strict;
use Carp;

use version; our $VERSION = qv('0.1.0');

use LWP::UserAgent;
use URI::Escape;

my %_tdfk_dict = qw/
北海道 ほっかいどう
青森県 あおもりけん
岩手県 いわてけん
宮城県 みやぎけん
秋田県 あきたけん
山形県 やまがたけん
福島県 ふくしまけん
茨城県 いばらきけん
栃木県 とちぎけん
群馬県 ぐんまけん
埼玉県 さいたまけん
千葉県 ちばけん
東京都 とうきょうと
神奈川県 かながわけん
富山県 とやまけん
新潟県 にいがたけん
石川県 いしかわけん
福井県 ふくいけん
山梨県 やまなしけん
長野県 ながのけん
岐阜県 ぎふけん
静岡県 しずおかけん
愛知県 あいちけん
三重県 みえけん
滋賀県 しがけん
京都府 きょうとふ
大阪府 おおさかふ
兵庫県 ひょうごけん
奈良県 ならけん
和歌山県 わかやまけん
鳥取県 とっとりけん
島根県 しまねけん
岡山県 おかやまけん
広島県 ひろしまけん
山口県 やまぐちけん
徳島県 とくしまけん
香川県 かがわけん
愛媛県 えひめけん
高知県 こうちけん
福岡県 ふくおかけん
佐賀県 さがけん
長崎県 ながさきけん
熊本県 くまもとけん
大分県 おおいたけん
宮崎県 みやざきけん
鹿児島県 かごしまけん
沖縄県 おきなわけん
/;

my $search_url_tpl = 'http://search.map.yahoo.co.jp/search?p=%s&ei=euc-jp';
my $kana_url_tpl   = 'http://map.yahoo.co.jp/address?ac=%s';


# コンストラクタ
sub new{ 
	my $class = shift;

	my %opt = ref($_[0]) ? %{$_[0]} : @_;

	my $ua = $opt{ua} || LWP::UserAgent->new();

	bless {ua => $ua}, $class;
};


# 概要: タグを取り除く
# 引数: HTML
# 戻値: タグを除いた文字列
sub _strip_tag{
	my $self = shift;
	my @strs = @_;
	return map { my $s = $_; $s =~ s/<[^>]+>//g; $s; } @strs;
}


# 概要: Yahoo Mapsにて、自由文検索を行う
# 引数: 検索語
# 戻値: 結果ページのHTML(無加工)
sub _do_freeword_search{
	my $self = shift;
	my $word = shift;

	my $url = sprintf($search_url_tpl, uri_escape($word));

	my $ua  = $self->{ua};
	my $res = $ua->get($url);
	return $res->content();
}


# 概要: 町字文字列を、Yahooで扱う町字文字列に変換
# 引数: 都道府県, (Yahoo書式の)市区文字列, 町字文字列
# 戻値: (Yahoo書式の)町字文字列
sub _correct_choaza{
	my $self = shift;
	my ($tdfk, $corrected_shiku, $choaza) = @_;

	my $html = $self->_do_freeword_search($tdfk . $corrected_shiku . $choaza);

	# 検索結果の一番最初を取る
	my $corrected_address = undef;
	if ($html =~ 
	       m{<a [^>]+http://map\.yahoo\.co\.jp/pl\?p=[^>]+>(.+?)</a>}) {
		$corrected_address = $1;
	}else{
		die "can't find $corrected_shiku, $choaza .";
	}

	# 市区部分を除く
	my $regex = quotemeta($tdfk. $corrected_shiku);
	$corrected_address =~ s/^$regex//;

	# 番地を省く
	$corrected_address =~ s/[0-9]+$//;

	# 丁目以降を除く
	$corrected_address =~ s/[0-9]+丁目$//;

	return $corrected_address;
}


# 概要: 市区文字列を、Yahooで扱う市区文字列に変換
# 引数: 都道府県文字列, 市区文字列
# 戻値: 市区ID, (Yahoo書式の)市区文字列
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

	# 都道府県の部分を除く
	my $regexp = quotemeta($tdfk);
	$corrected_shiku =~ s/^$regexp//;

	return ($code, $corrected_shiku);
}


# 概要: 市区に対応するフリガナの一覧を得る
# 引数: 市区ID
# 戻値: ハッシュリファレンス {漢字1 => かな1, 漢字2 => かな2, ...}
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


# 概要: 県名、市区、町字に対するかなを返す
# 引数: 県名、市区、町字
# 戻値: けんめい、しく、ちょうあざ
sub search{
	my $self = shift;
	my ($tdfk, $shiku, $choaza) = @_;

	# 仮名を得るために市区IDが必要。副作用でYahoo表現の市区も手に入る。
	my ($shiku_code, $corrected_shiku) = $self->_correct_shiku($tdfk, $shiku);
	my $tdfk_code = substr($shiku_code, 0, 2);

	my $ref_choaza = $self->_get_kana_dict($shiku_code);
	my $ref_shiku  = $self->_get_kana_dict($tdfk_code);

	# 市区
	my $shiku_kana = $ref_shiku->{$corrected_shiku};

	# 町字
	my $corrected_choaza = '';
	my $choaza_kana = '';
	if(exists $ref_choaza->{$choaza}){
	    # 変換せずに見つかった
	    $choaza_kana = $ref_choaza->{$choaza};
	}else{
	    # Yahoo表現に変換し、再チャレンジ
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
    print $yahoo->search('山梨県', '鰍沢町', '鳥屋'), "\n";

results:

    やまなしけんかじかざわちょうとや

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

Prefecture in Japan, should be ended with '都' or '道' or '府' or '県'.

=item $shiku

Name of city and district, should be ended with '市' or '区' or '町' or '村'.

=item $choaza

The rest of the string of address. It might contain '町' and '字'.

=back

You can use a vague address to some degree. For example: 

    print $yahoo->search('茨城県', '龍ヶ崎市', '米町'), "\n";
    print $yahoo->search('茨城県', '龍崎市', '米町'), "\n";
    print $yahoo->search('茨城県', '竜が崎市', '米町'), "\n";

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
