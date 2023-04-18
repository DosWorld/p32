program GenDate;

uses dos;

const
  days : array [0..6] of String[9] =
    ('Sunday','Monday','Tuesday',
     'Wednesday','Thursday','Friday',
     'Saturday');
  months : array [1..12] of String[3] =
    ('Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec');

var
  y, m, d, dow : Word;
  f:text;

begin
  GetDate(y,m,d,dow);
  Assign(f,'date.inc');
  Rewrite(f);
  Writeln(f,'compiledate = ''',days[dow],' ',d, '-', months[m], '-', y,''';');
  Close(f);
end.
