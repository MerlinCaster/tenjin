## name: 
## desc: append (multilines)
_buf = []; _buf.append('''<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN"
          "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en" lang="en">
 <head>
  <title>Stock Prices</title>
  <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
  <meta http-equiv="Content-Style-Type" content="text/css" />
  <meta http-equiv="Content-Script-Type" content="text/javascript" />
  <link rel="shortcut icon" href="/images/favicon.ico" />
  <link rel="stylesheet" type="text/css" href="/css/style.css" media="all" />
  <script type="text/javascript" src="/js/util.js"></script>
  <style type="text/css">
  /*<![CDATA[*/

body {
    color: #333333;
    line-height: 150%;
}

thead {
    font-weight: bold;
    background-color: #CCCCCC;
}

.odd {
    background-color: #FFCCCC;
}

.even {
    background-color: #CCCCFF;
}

.minus {
    color: #FF0000;
}

  /*]]>*/
  </style>

 </head>

 <body>

  <h1>Stock Prices</h1>

  <table>
   <thead>
    <tr>
     <th>#</th><th>symbol</th><th>name</th><th>price</th><th>change</th><th>ratio</th>
    </tr>
   </thead>
   <tbody>\n''');

n = 0
for item in items:
    n += 1

    _buf.append('''    <tr class="'''); _buf.append(n % 2 and 'odd' or 'even'); _buf.append('''">
     <td style="text-align: center">'''); _buf.append(str(n)); _buf.append('''</td>
     <td>
      <a href="/stocks/'''); _buf.append(item.symbol); _buf.append('''">'''); _buf.append(item.symbol); _buf.append('''</a>
     </td>
     <td>
      <a href="'''); _buf.append(item.url); _buf.append('''">'''); _buf.append(item.name); _buf.append('''</a>
     </td>
     <td>
      <strong>'''); _buf.append(item.s_price); _buf.append('''</strong>
     </td>\n''');
    if item.change < 0.0:
        _buf.append('''     <td class="minus">'''); _buf.append(item.s_change); _buf.append('''</td>
     <td class="minus">'''); _buf.append(item.s_ratio); _buf.append('''</td>\n''');
    else:
        _buf.append('''     <td>'''); _buf.append(item.s_change); _buf.append('''</td>
     <td>'''); _buf.append(item.s_ratio); _buf.append('''</td>\n''');
    #endif
    _buf.append('''    </tr>\n''');

#endfor

_buf.append('''   </tbody>
  </table>

 </body>
</html>\n''');
_result = ''.join(_buf)
