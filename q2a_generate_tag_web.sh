cat <<EOFSTART
<html>
  <body>
    <script src="http://ajax.googleapis.com/ajax/libs/jquery/1.3.2/jquery.min.js"></script>
    <script src="springy.js"></script>
    <script src="springyui.js"></script>
    <script>
      var graph = new Springy.Graph();
      var nodes = {};

EOFSTART

mysql -p --silent -e "
  select 
    count(*), a.word, b.word
  from 
    (select 
       postid, word 
     from qa_posttags
     join qa_words using (wordid)) a
  join
    (select
       postid, word
     from qa_posttags
     join qa_words using (wordid)) b
  using (postid)
  where a.word > b.word
  group by a.word, b.word
  order by a.word, b.word
  limit 50;" q2adb | \
while read c w1 w2; do
  echo "      if (!('$w1' in nodes)) nodes['$w1'] = graph.newNode({label: '$w1'});"
  echo "      if (!('$w2' in nodes)) nodes['$w2'] = graph.newNode({label: '$w2'});"
  echo "      graph.newEdge(nodes['$w1'], nodes['$w2'], {directional: false, weight: $c, color: '#00A0B0'});"
  echo
done

cat <<EOFEND
      jQuery(function(){
        var springy = window.springy = jQuery('#springydemo').springy({
          graph: graph
        });
      });
    </script>

    <canvas id="springydemo" width="640" height="480" />
  </body>
</html>
EOFEND

