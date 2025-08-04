{% macro
    angstrom_bundle_tob_order_volume(raw_tx_input_hex)
%}


SELECT
    seed.txi, 
    tob_vs.quantity_in AS quantity_in,
    tob_vs.quantity_out AS quantity_out,
    tob_vs.asset_in AS asset_in,
    tob_vs.asset_out AS asset_out,
    tob_vs.recipient AS recipient
FROM (
    SELECT {{ raw_tx_input_hex }} AS txi
) AS seed
CROSS JOIN LATERAL (
    SELECT 
        ab.*,
        asts.*
    FROM ({{angstrom_decoding_top_of_block_orders('seed.txi')}}) AS ab
    CROSS JOIN LATERAL ({{ angstrom_bundle_indexes_to_assets('seed.txi', 'ab.pairs_index', 'ab.zero_for_1') }}) AS asts
) AS tob_vs


{% endmacro %}
