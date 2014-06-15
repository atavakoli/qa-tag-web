#!/bin/bash

export TOP_N_TAGS=50
export EDGE_WEIGHT_CUTOFF=2

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
  create temporary table if not exists popular_posttags_a as
    (select count(postid) as postcount, wordid
     from qa_posttags
     group by wordid
     order by postcount desc
     limit $TOP_N_TAGS);

  create temporary table if not exists popular_posttags_b as
    (select count(postid) as postcount, wordid
     from qa_posttags
     group by wordid
     order by postcount desc
     limit $TOP_N_TAGS);

  select 
    count(*) as weight, a.word, a.postcount, b.word, b.postcount
  from 
    (select 
       postid, word, postcount
     from qa_posttags
     join popular_posttags_a using (wordid)
     join qa_words using (wordid)) a
  join
    (select
       postid, word, postcount
     from qa_posttags
     join popular_posttags_b using (wordid)
     join qa_words using (wordid)) b
  using (postid)
  where a.word > b.word
  group by a.word, a.postcount, b.word, b.postcount
  having weight >= $EDGE_WEIGHT_CUTOFF
  order by a.word, b.word;" q2adb | \
while read c w1 w1c w2 w2c; do
  echo "      if (!('$w1' in nodes)) nodes['$w1'] = graph.newNode({label: '$w1 ($w1c)'});"
  echo "      if (!('$w2' in nodes)) nodes['$w2'] = graph.newNode({label: '$w2 ($w2c)'});"
  echo "      graph.newEdge(nodes['$w1'], nodes['$w2'], {directional: false, label: $c, weight: $c, color: '#00A0B0'});"
  echo
done

cat <<EOFEND
      jQuery(function(){
        var springy = window.springy = jQuery('#springydemo').springy({
          graph: graph
        });
      });
    </script>

    <canvas id="springydemo" width="1280" height="1024" />
  </body>
</html>
EOFEND

