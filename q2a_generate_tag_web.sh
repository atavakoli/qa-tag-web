#!/bin/bash

export TOP_N_TAGS=50
export EDGE_WEIGHT_CUTOFF=2

export MIN_NODE_SIZE=9
export MAX_NODE_SIZE=18

export MIN_EDGE_SIZE=1
export MAX_EDGE_SIZE=4

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

export TMP_FILE=/tmp/$$.txt

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
  order by a.word, b.word;" q2adb > "$TMP_FILE"

export MIN_NODE_WEIGHT=255
export MAX_NODE_WEIGHT=0

export MIN_EDGE_WEIGHT=255
export MAX_EDGE_WEIGHT=0

while read c w1 w1c w2 w2c; do
  if [ $w1c -gt $MAX_NODE_WEIGHT ]; then
    export MAX_NODE_WEIGHT=$w1c
  fi
  if [ $w1c -lt $MIN_NODE_WEIGHT ]; then
    export MIN_NODE_WEIGHT=$w1c
  fi

  if [ $w2c -gt $MAX_NODE_WEIGHT ]; then
    export MAX_NODE_WEIGHT=$w2c
  fi
  if [ $w2c -lt $MIN_NODE_WEIGHT ]; then
    export MIN_NODE_WEIGHT=$w2c
  fi

  if [ $c -gt $MAX_EDGE_WEIGHT ]; then
    export MAX_EDGE_WEIGHT=$c
  fi
  if [ $c -lt $MIN_EDGE_WEIGHT ]; then
    export MIN_EDGE_WEIGHT=$c
  fi
done < "$TMP_FILE"

echo "NODES: $MIN_NODE_WEIGHT - $MAX_NODE_WEIGHT" > /dev/stderr
echo "EDGES: $MIN_EDGE_WEIGHT - $MAX_EDGE_WEIGHT" > /dev/stderr

if [ "$MIN_NODE_WEIGHT" == "$MAX_NODE_WEIGHT" ]; then
  export $IS_FIXED_NODE_SIZE=t
else
  export NODE_SIZE_DIFF=$(echo "scale=1; $MAX_NODE_SIZE - $MIN_NODE_SIZE" | bc)
  export NODE_WEIGHT_DIFF=$(echo "$MAX_NODE_WEIGHT - $MIN_NODE_WEIGHT" | bc)
fi

if [ "$MIN_EDGE_WEIGHT" == "$MAX_EDGE_WEIGHT" ]; then
  export $IS_FIXED_EDGE_SIZE=t
else
  export EDGE_SIZE_DIFF=$(echo "scale=1; $MAX_EDGE_SIZE - $MIN_EDGE_SIZE" | bc)
  export EDGE_WEIGHT_DIFF=$(echo "$MAX_EDGE_WEIGHT - $MIN_EDGE_WEIGHT" | bc)
fi

while read c w1 w1c w2 w2c; do
  if [ -n "$IS_FIXED_NODE_SIZE" ]; then
    export w1font=$MIN_NODE_SIZE
    export w2font=$MIN_NODE_SIZE
  else
    export w1font=$(echo "scale=7; $MIN_NODE_SIZE + $NODE_SIZE_DIFF * ($w1c - $MIN_NODE_WEIGHT) / $NODE_WEIGHT_DIFF" | bc)
    export w2font=$(echo "scale=7; $MIN_NODE_SIZE + $NODE_SIZE_DIFF * ($w2c - $MIN_NODE_WEIGHT) / $NODE_WEIGHT_DIFF" | bc)
  fi

  if [ -n "$IS_FIXED_EDGE_SIZE" ]; then
    export edgeweight=$MIN_EDGE_SIZE
  else
    export edgeweight=$(echo "scale=7; $MIN_EDGE_SIZE + $EDGE_SIZE_DIFF * ($c - $MIN_EDGE_WEIGHT) / $EDGE_WEIGHT_DIFF" | bc)
  fi

  echo "      if (!('$w1' in nodes)) nodes['$w1'] = graph.newNode({label: '$w1 ($w1c)', font: '${w1font}px Verdana, sans-serif'});"
  echo "      if (!('$w2' in nodes)) nodes['$w2'] = graph.newNode({label: '$w2 ($w2c)', font: '${w2font}px Verdana, sans-serif'});"
  echo "      graph.newEdge(nodes['$w1'], nodes['$w2'], {directional: false, label: $c, weight: $edgeweight, color: '#00A0B0'});"
  echo
done < "$TMP_FILE"

rm -f "$TMP_FILE"

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

