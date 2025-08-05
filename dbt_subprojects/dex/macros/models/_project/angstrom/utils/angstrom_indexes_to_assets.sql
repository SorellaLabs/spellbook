{% macro
    angstrom_bundle_indexes_to_assets(raw_tx_input_hex, pair_index, zfo)
%}

WITH
    params AS (
        SELECT {{ pair_index }} AS this_pair_index

    ),
    assets AS (
        SELECT *
        FROM ({{angstrom_decoding_assets(raw_tx_input_hex)}})
    ),
    all_pairs AS (
        SELECT 
            bundle_idx,
            index0,
            index1,
            price_1over0
        FROM ({{angstrom_decoding_pairs(raw_tx_input_hex)}})
    )
    pairs AS (
        SELECT 
            bundle_idx,
            index0,
            index1,
            price_1over0
        FROM all_pairs
        JOIN params ON bundle_idx = this_pair_index
    ),
    _asset_in AS (
        SELECT
            price_1over0,
            token_address AS asset_in
        FROM assets AS a
        CROSS JOIN pairs AS p
        WHERE a.bundle_idx = p.index0 AND p.bundle_idx = {{ pair_index }}
    ),
    _asset_out AS (
        SELECT
            token_address AS asset_out
        FROM assets AS a
        CROSS JOIN pairs AS p
        WHERE a.bundle_idx = p.index1 AND p.bundle_idx = {{ pair_index }}
    ),
    zfo_assets AS (
        SELECT
            price_1over0,
            if({{ zfo }}, ARRAY[asset_in, asset_out], ARRAY[asset_out, asset_in]) AS zfo_sorted_assets
        FROM _asset_in i 
        CROSS JOIN _asset_out o
    )
SELECT
    zfo_sorted_assets[1] AS asset_in,
    zfo_sorted_assets[2] AS asset_out,
    price_1over0
FROM zfo_assets



{% endmacro %}
