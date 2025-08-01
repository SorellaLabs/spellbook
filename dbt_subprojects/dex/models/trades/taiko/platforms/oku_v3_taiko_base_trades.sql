{{
    config(
        schema = 'oku_v3_taiko',
        alias = 'base_trades',
        materialized = 'incremental',
        file_format = 'delta',
        incremental_strategy = 'merge',
        unique_key = ['tx_hash', 'evt_index'],
        incremental_predicates = [incremental_predicate('DBT_INTERNAL_DEST.block_time')]
    )
}}

{{
    uniswap_compatible_v3_trades(
        blockchain = 'taiko',
        project = 'oku',
        version = '3',
        Pair_evt_Swap = source('oku_taiko', 'V3Pool_evt_Swap'),
        Factory_evt_PoolCreated = source('oku_taiko', 'V3Factory_evt_PoolCreated')
    )
}}
