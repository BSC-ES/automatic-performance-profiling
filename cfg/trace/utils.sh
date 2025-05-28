#!/bin/bash

#####################################################################################################################
# Brief: Cut the whole model trace by its components
# Param: 
#   $1 - Components names array name
#   $2 - Components processors array name
#   $3 - Trace file *.prv
#####################################################################################################################
function cut_trace()
{
    local -n components_names="$1"
    local -n components_processors="$2"
    local trace_file=$3

    local first_proc=1
    local i=0
    while [ $i -lt ${#components_names[@]} ]; do
        local component_procs=${components_processors[i]}
        local last_proc=$((first_proc+component_procs-1))

        cat << EOF > cutter.xml
<?xml version="1.0" encoding="UTF-8"?>
<config>
  <!-- CUTTER OPTIONS -->
  <cutter>
    <tasks>${first_proc}-${last_proc}</tasks>
    <max_trace_size>0</max_trace_size>
    <by_time>0</by_time>
    <minimum_time>0</minimum_time>
    <maximum_time>0</maximum_time>
    <minimum_time_percentage>0</minimum_time_percentage>
    <maximum_time_percentage>100</maximum_time_percentage>
    <original_time>0</original_time>
    <break_states>1</break_states>
    <remove_first_states>0</remove_first_states>
    <remove_last_states>0</remove_last_states>
    <keep_events>0</keep_events>
  </cutter>
</config>
EOF
        paramedir -c cutter.xml ${trace_file}

        mv ${model}.chop*.prv ${components_names[i]}.prv
        mv ${model}.chop*.pcf ${components_names[i]}.pcf
        mv ${model}.chop*.row ${components_names[i]}.row

        first_proc=$((last_proc+1))
        i=$((i+1))
    done
}