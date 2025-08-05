{% macro
    angstrom_bundle_volume_events(   
        angstrom_contract_addr, 
        blockchain,
        project = null,
        version = null
    )
%}


WITH
    tx_data_cte AS (
        SELECT 
            block_number,
            block_time,
            hash AS tx_hash,
            index AS tx_index,
            to AS angstrom_address,
            data AS tx_data
        FROM {{ source(blockchain, 'transactions') }}
        WHERE to = {{ angstrom_contract_addr }} AND varbinary_substring(data, 1, 4) = 0x09c5eabe AND hash = 0x47aefe13a19c8036c0985b59090a34adffcad108630a86aae298954554394d10
    ),
    tob_orders AS (
        SELECT 
            t.block_number AS block_number,
            t.block_time AS block_time,
            t.angstrom_address AS maker,
            t.angstrom_address AS project_contract_address,
            t.tx_hash AS tx_hash,
            row_number() over (partition by t.tx_hash) as evt_index,
            p.*
        FROM tx_data_cte t
        CROSS JOIN LATERAL ({{ angstrom_bundle_tob_order_volume('t.tx_data') }}) AS p
    )
SELECT
   *
FROM tob_orders



{% endmacro %}
