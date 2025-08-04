with
    dexs as (

        with
            tx_data_cte as (
                select
                    block_number,
                    block_time,
                    tx_hash,
                    tx_index,
                    angstrom_address,
                    tx_data
                from
                    (
                        select
                            t.block_number as block_number,
                            t.block_time as block_time,
                            t.hash as tx_hash,
                            t.index as tx_index,
                            t.to as angstrom_address,
                            t.data as tx_data
                        from "delta_prod"."ethereum"."transactions" as t
                        where
                            t.to = 0xb9c4ce42c2e29132e207d29af6a7719065ca6aec
                            and varbinary_substring(t.data, 1, 4) = 0x09c5eabe
                            and t.hash
                            = 0x47aefe13a19c8036c0985b59090a34adffcad108630a86aae298954554394d10
                    )
            ),
            tob_orders as (
                select
                    t.block_number as block_number,
                    t.block_time as block_time,
                    p.quantity_in as token_bought_amount_raw,
                    p.quantity_out as token_sold_amount_raw,
                    p.asset_in as token_bought_address,
                    p.asset_out as token_sold_address,
                    p.recipient as taker,
                    t.angstrom_address as maker,
                    t.angstrom_address as project_contract_address,
                    t.tx_hash as tx_hash,
                    t.tx_data AS tx_data,
                    row_number() over (partition by t.tx_hash) as evt_index
                from tx_data_cte t
                cross join
                    lateral (
                        select
                            seed.txi,
                            tob_vs.quantity_in as quantity_in,
                            tob_vs.quantity_out as quantity_out,
                            tob_vs.asset_in as asset_in,
                            tob_vs.asset_out as asset_out,
                            tob_vs.recipient as recipient
                        from (select t.tx_data as txi) as seed
                        cross join
                            lateral (
                                select ab.*, asts.*
                                from
                                    (

                                        with
                                            vec_pade as (
                                                select seed.txi, tob_decode_vs.*
                                                from (select seed.txi as txi) as seed
                                                cross join
                                                    lateral (
                                                        select buf, seed.txi
                                                        from
                                                            (
                                                                -- 0. assets, 1.
                                                                -- pairs, 2.
                                                                -- pool_updates, 3.
                                                                -- top_of_block_orders, 4. user_orders
                                                                with
                                                                    trimmed_input as (
                                                                        select
                                                                            1
                                                                            as next_offset,
                                                                            varbinary_substring(
                                                                                seed.txi,
                                                                                69
                                                                            )
                                                                            as next_buf
                                                                    ),
                                                                    -- assets
                                                                    step0 as (
                                                                        select len + 3 +
                                                                        offset
                                                                            as next_offset,
                                                                            varbinary_substring(
                                                                                next_buf,
                                                                                offset,
                                                                                len + 3
                                                                            ) as buf,
                                                                            next_buf
                                                                        from
                                                                            (
                                                                                select
                                                                                    next_offset
                                                                                    as offset,
                                                                                    varbinary_to_integer(
                                                                                        varbinary_substring(
                                                                                            next_buf,
                                                                                            next_offset,
                                                                                            3
                                                                                        )
                                                                                    )
                                                                                    as len,
                                                                                    next_buf
                                                                                from
                                                                                    trimmed_input
                                                                            )
                                                                    ),
                                                                    -- pairs
                                                                    step1 as (
                                                                        select len + 3 +
                                                                        offset
                                                                            as next_offset,
                                                                            varbinary_substring(
                                                                                next_buf,
                                                                                offset,
                                                                                len + 3
                                                                            ) as buf,
                                                                            next_buf
                                                                        from
                                                                            (
                                                                                select
                                                                                    next_offset
                                                                                    as offset,
                                                                                    varbinary_to_integer(
                                                                                        varbinary_substring(
                                                                                            next_buf,
                                                                                            next_offset,
                                                                                            3
                                                                                        )
                                                                                    )
                                                                                    as len,
                                                                                    next_buf
                                                                                from
                                                                                    step0
                                                                            )
                                                                    ),
                                                                    -- pool updates
                                                                    step2 as (
                                                                        select len + 3 +
                                                                        offset
                                                                            as next_offset,
                                                                            varbinary_substring(
                                                                                next_buf,
                                                                                offset,
                                                                                len + 3
                                                                            ) as buf,
                                                                            next_buf
                                                                        from
                                                                            (
                                                                                select
                                                                                    next_offset
                                                                                    as offset,
                                                                                    varbinary_to_integer(
                                                                                        varbinary_substring(
                                                                                            next_buf,
                                                                                            next_offset,
                                                                                            3
                                                                                        )
                                                                                    )
                                                                                    as len,
                                                                                    next_buf
                                                                                from
                                                                                    step1
                                                                            )
                                                                    ),
                                                                    -- top of block
                                                                    -- orders
                                                                    step3 as (
                                                                        select len + 3 +
                                                                        offset
                                                                            as next_offset,
                                                                            varbinary_substring(
                                                                                next_buf,
                                                                                offset,
                                                                                len + 3
                                                                            ) as buf,
                                                                            next_buf
                                                                        from
                                                                            (
                                                                                select
                                                                                    next_offset
                                                                                    as offset,
                                                                                    varbinary_to_integer(
                                                                                        varbinary_substring(
                                                                                            next_buf,
                                                                                            next_offset,
                                                                                            3
                                                                                        )
                                                                                    )
                                                                                    as len,
                                                                                    next_buf
                                                                                from
                                                                                    step2
                                                                            )
                                                                    ),
                                                                    -- user orders
                                                                    step4 as (
                                                                        select len + 3 +
                                                                        offset
                                                                            as next_offset,
                                                                            varbinary_substring(
                                                                                next_buf,
                                                                                offset,
                                                                                len + 3
                                                                            ) as buf,
                                                                            next_buf
                                                                        from
                                                                            (
                                                                                select
                                                                                    next_offset
                                                                                    as offset,
                                                                                    varbinary_to_integer(
                                                                                        varbinary_substring(
                                                                                            next_buf,
                                                                                            next_offset,
                                                                                            3
                                                                                        )
                                                                                    )
                                                                                    as len,
                                                                                    next_buf
                                                                                from
                                                                                    step3
                                                                            )
                                                                    )
                                                                select
                                                                    seed.txi,
                                                                    buf_rec_vs.buf
                                                                    as buf
                                                                from
                                                                    (
                                                                        select
                                                                            t.tx_data
                                                                            as txi
                                                                    ) as seed
                                                                cross join
                                                                    lateral (
                                                                        select buf
                                                                        from step3
                                                                    ) as buf_rec_vs

                                                            )
                                                    ) as tob_decode_vs
                                            )
                                        select
                                            use_internal,
                                            quantity_in,
                                            quantity_out,
                                            max_gas_asset_0,
                                            gas_used_asset_0,
                                            pairs_index,
                                            zero_for_1,
                                            recipient,
                                            signature_kind,
                                            signature_ecdsa_v,
                                            signature_ecdsa_r,
                                            signature_ecdsa_s,
                                            signature_contract_from,
                                            signature_contract_signature
                                        from
                                            (
                                                with recursive
                                                    decode_tob_order(
                                                        buf,
                                                        pointer,
                                                        idx,
                                                        use_internal,
                                                        quantity_in,
                                                        quantity_out,
                                                        max_gas_asset_0,
                                                        gas_used_asset_0,
                                                        pairs_index,
                                                        zero_for_1,
                                                        recipient,
                                                        signature_kind,
                                                        signature_ecdsa_v,
                                                        signature_ecdsa_r,
                                                        signature_ecdsa_s,
                                                        signature_contract_from,
                                                        signature_contract_signature
                                                    ) as (
                                                        select
                                                            varbinary_substring(
                                                                buf,
                                                                4,
                                                                varbinary_length(buf)
                                                                - 3
                                                            ),
                                                            4,
                                                            0,
                                                            cast(null as boolean),
                                                            cast(null as uint256),
                                                            cast(null as uint256),
                                                            cast(null as uint256),
                                                            cast(null as uint256),
                                                            cast(null as bigint),
                                                            cast(null as boolean),
                                                            cast(null as varbinary),
                                                            cast(null as varchar),
                                                            cast(null as bigint),
                                                            cast(null as varbinary),
                                                            cast(null as varbinary),
                                                            cast(null as varbinary),
                                                            cast(null as varbinary)
                                                        from vec_pade

                                                        union all

                                                        select
                                                            buf,
                                                            pointer,
                                                            idx,
                                                            use_internal,
                                                            quantity_in,
                                                            quantity_out,
                                                            max_gas_asset_0,
                                                            gas_used_asset_0,
                                                            pairs_index,
                                                            zero_for_1,
                                                            recipient,
                                                            signature_kind,
                                                            signature_ecdsa_v,
                                                            signature_ecdsa_r,
                                                            signature_ecdsa_s,
                                                            signature_contract_from,
                                                            signature_contract_signature
                                                        from
                                                            (
                                                                with
                                                                    trimmed_as_fields
                                                                    as (
                                                                        select
                                                                            idx
                                                                            + 1 as idx,
                                                                            array[
                                                                                bitwise_and(
                                                                                    bitwise_right_shift(
                                                                                        varbinary_to_integer(
                                                                                            varbinary_substring(
                                                                                                buf,
                                                                                                1,
                                                                                                1
                                                                                            )
                                                                                        ),
                                                                                        3
                                                                                    ),
                                                                                    1
                                                                                ),
                                                                                bitwise_and(
                                                                                    bitwise_right_shift(
                                                                                        varbinary_to_integer(
                                                                                            varbinary_substring(
                                                                                                buf,
                                                                                                1,
                                                                                                1
                                                                                            )
                                                                                        ),
                                                                                        2
                                                                                    ),
                                                                                    1
                                                                                ),
                                                                                bitwise_and(
                                                                                    bitwise_right_shift(
                                                                                        varbinary_to_integer(
                                                                                            varbinary_substring(
                                                                                                buf,
                                                                                                1,
                                                                                                1
                                                                                            )
                                                                                        ),
                                                                                        1
                                                                                    ),
                                                                                    1
                                                                                ),
                                                                                bitwise_and(
                                                                                    varbinary_to_integer(
                                                                                        varbinary_substring(
                                                                                            buf,
                                                                                            1,
                                                                                            1
                                                                                        )
                                                                                    ),
                                                                                    1
                                                                                )
                                                                            ] as bitmap,
                                                                            buf,
                                                                            2 as pointer
                                                                        from
                                                                            decode_tob_order
                                                                    ),
                                                                    use_internal_field
                                                                    as (
                                                                        select
                                                                            idx,
                                                                            if(
                                                                                bitmap[
                                                                                    4
                                                                                ]
                                                                                = 1,
                                                                                true,
                                                                                false
                                                                            )
                                                                            as use_internal,
                                                                            bitmap,
                                                                            pointer,
                                                                            buf
                                                                        from
                                                                            trimmed_as_fields
                                                                    ),
                                                                    quantity_in_field
                                                                    as (
                                                                        select
                                                                            idx,
                                                                            use_internal,
                                                                            varbinary_to_uint256(
                                                                                varbinary_substring(
                                                                                    buf,
                                                                                    pointer,
                                                                                    16
                                                                                )
                                                                            )
                                                                            as quantity_in,
                                                                            bitmap,
                                                                            pointer
                                                                            + 16
                                                                            as pointer,
                                                                            buf
                                                                        from
                                                                            use_internal_field
                                                                    ),
                                                                    quantity_out_field
                                                                    as (
                                                                        select
                                                                            idx,
                                                                            use_internal,
                                                                            quantity_in,
                                                                            varbinary_to_uint256(
                                                                                varbinary_substring(
                                                                                    buf,
                                                                                    pointer,
                                                                                    16
                                                                                )
                                                                            )
                                                                            as quantity_out,
                                                                            bitmap,
                                                                            pointer
                                                                            + 16
                                                                            as pointer,
                                                                            buf
                                                                        from
                                                                            quantity_in_field
                                                                    ),
                                                                    max_gas_asset_0_field
                                                                    as (
                                                                        select
                                                                            idx,
                                                                            use_internal,
                                                                            quantity_in,
                                                                            quantity_out,
                                                                            varbinary_to_uint256(
                                                                                varbinary_substring(
                                                                                    buf,
                                                                                    pointer,
                                                                                    16
                                                                                )
                                                                            )
                                                                            as max_gas_asset_0,
                                                                            bitmap,
                                                                            pointer
                                                                            + 16
                                                                            as pointer,
                                                                            buf
                                                                        from
                                                                            quantity_out_field
                                                                    ),
                                                                    gas_used_asset_0_field
                                                                    as (
                                                                        select
                                                                            idx,
                                                                            use_internal,
                                                                            quantity_in,
                                                                            quantity_out,
                                                                            max_gas_asset_0,
                                                                            varbinary_to_uint256(
                                                                                varbinary_substring(
                                                                                    buf,
                                                                                    pointer,
                                                                                    16
                                                                                )
                                                                            )
                                                                            as gas_used_asset_0,
                                                                            bitmap,
                                                                            pointer
                                                                            + 16
                                                                            as pointer,
                                                                            buf
                                                                        from
                                                                            max_gas_asset_0_field
                                                                    ),
                                                                    pairs_index_field
                                                                    as (
                                                                        select
                                                                            idx,
                                                                            use_internal,
                                                                            quantity_in,
                                                                            quantity_out,
                                                                            max_gas_asset_0,
                                                                            gas_used_asset_0,
                                                                            varbinary_to_bigint(
                                                                                varbinary_substring(
                                                                                    buf,
                                                                                    pointer,
                                                                                    2
                                                                                )
                                                                            )
                                                                            as pairs_index,
                                                                            bitmap,
                                                                            pointer
                                                                            + 2
                                                                            as pointer,
                                                                            buf
                                                                        from
                                                                            gas_used_asset_0_field
                                                                    ),
                                                                    zero_for_1_field
                                                                    as (
                                                                        select
                                                                            idx,
                                                                            use_internal,
                                                                            quantity_in,
                                                                            quantity_out,
                                                                            max_gas_asset_0,
                                                                            gas_used_asset_0,
                                                                            pairs_index,
                                                                            if(
                                                                                bitmap[
                                                                                    3
                                                                                ]
                                                                                = 1,
                                                                                true,
                                                                                false
                                                                            )
                                                                            as zero_for_1,
                                                                            bitmap,
                                                                            pointer,
                                                                            buf
                                                                        from
                                                                            pairs_index_field
                                                                    ),
                                                                    recipient_field as (
                                                                        select
                                                                            idx,
                                                                            use_internal,
                                                                            quantity_in,
                                                                            quantity_out,
                                                                            max_gas_asset_0,
                                                                            gas_used_asset_0,
                                                                            pairs_index,
                                                                            zero_for_1,
                                                                            if(
                                                                                bitmap[
                                                                                    2
                                                                                ]
                                                                                = 1,
                                                                                varbinary_substring(
                                                                                    buf,
                                                                                    pointer,
                                                                                    20
                                                                                ),
                                                                                null
                                                                            )
                                                                            as recipient,
                                                                            bitmap,
                                                                            if(
                                                                                bitmap[
                                                                                    2
                                                                                ]
                                                                                = 1,
                                                                                pointer
                                                                                + 20,
                                                                                pointer
                                                                            )
                                                                            as pointer,
                                                                            buf
                                                                        from
                                                                            zero_for_1_field
                                                                    ),
                                                                    signature_field as (
                                                                        select
                                                                            idx,
                                                                            use_internal,
                                                                            quantity_in,
                                                                            quantity_out,
                                                                            max_gas_asset_0,
                                                                            gas_used_asset_0,
                                                                            pairs_index,
                                                                            zero_for_1,
                                                                            recipient,
                                                                            if(
                                                                                bitmap[
                                                                                    1
                                                                                ]
                                                                                = 1,
                                                                                'Ecdsa',
                                                                                'Contract'
                                                                            )
                                                                            as signature_kind,
                                                                            if(
                                                                                bitmap[
                                                                                    1
                                                                                ]
                                                                                = 1,
                                                                                varbinary_to_bigint(
                                                                                    varbinary_substring(
                                                                                        buf,
                                                                                        pointer,
                                                                                        1
                                                                                    )
                                                                                ),
                                                                                null
                                                                            )
                                                                            as signature_ecdsa_v,
                                                                            if(
                                                                                bitmap[
                                                                                    1
                                                                                ]
                                                                                = 1,
                                                                                varbinary_substring(
                                                                                    buf,
                                                                                    pointer
                                                                                    + 1,
                                                                                    32
                                                                                ),
                                                                                null
                                                                            )
                                                                            as signature_ecdsa_r,
                                                                            if(
                                                                                bitmap[
                                                                                    1
                                                                                ]
                                                                                = 1,
                                                                                varbinary_substring(
                                                                                    buf,
                                                                                    pointer
                                                                                    + 33,
                                                                                    32
                                                                                ),
                                                                                null
                                                                            )
                                                                            as signature_ecdsa_s,
                                                                            if(
                                                                                bitmap[
                                                                                    1
                                                                                ]
                                                                                = 0,
                                                                                varbinary_substring(
                                                                                    buf,
                                                                                    pointer,
                                                                                    20
                                                                                ),
                                                                                null
                                                                            )
                                                                            as signature_contract_from,
                                                                            if(
                                                                                bitmap[
                                                                                    1
                                                                                ]
                                                                                = 0,
                                                                                varbinary_substring(
                                                                                    buf,
                                                                                    pointer
                                                                                    + 23,
                                                                                    varbinary_to_integer(
                                                                                        varbinary_substring(
                                                                                            buf,
                                                                                            pointer
                                                                                            + 20,
                                                                                            3
                                                                                        )
                                                                                    )
                                                                                ),
                                                                                null
                                                                            )
                                                                            as signature_contract_signature,
                                                                            bitmap,
                                                                            if(
                                                                                bitmap[
                                                                                    1
                                                                                ]
                                                                                = 1,
                                                                                pointer
                                                                                + 65,
                                                                                pointer
                                                                                + 23
                                                                                + varbinary_to_integer(
                                                                                    varbinary_substring(
                                                                                        buf,
                                                                                        pointer
                                                                                        + 20,
                                                                                        3
                                                                                    )
                                                                                )
                                                                            )
                                                                            as pointer,
                                                                            buf
                                                                        from
                                                                            recipient_field
                                                                    ),
                                                                    all_fields_collapsed
                                                                    as (
                                                                        select
                                                                            buf,
                                                                            pointer,
                                                                            idx,
                                                                            use_internal,
                                                                            quantity_in,
                                                                            quantity_out,
                                                                            max_gas_asset_0,
                                                                            gas_used_asset_0,
                                                                            pairs_index,
                                                                            zero_for_1,
                                                                            recipient,
                                                                            signature_kind,
                                                                            signature_ecdsa_v,
                                                                            signature_ecdsa_r,
                                                                            signature_ecdsa_s,
                                                                            signature_contract_from,
                                                                            signature_contract_signature
                                                                        from
                                                                            signature_field
                                                                    )
                                                                select
                                                                    varbinary_substring(
                                                                        buf, pointer
                                                                    ) as buf,
                                                                    pointer,
                                                                    idx,
                                                                    use_internal,
                                                                    quantity_in,
                                                                    quantity_out,
                                                                    max_gas_asset_0,
                                                                    gas_used_asset_0,
                                                                    pairs_index,
                                                                    zero_for_1,
                                                                    recipient,
                                                                    signature_kind,
                                                                    signature_ecdsa_v,
                                                                    signature_ecdsa_r,
                                                                    signature_ecdsa_s,
                                                                    signature_contract_from,
                                                                    signature_contract_signature
                                                                from
                                                                    all_fields_collapsed
                                                                where
                                                                    varbinary_length(
                                                                        buf
                                                                    )
                                                                    != 0
                                                            )
                                                    )
                                                select *
                                                from decode_tob_order
                                                where idx > 0
                                            )
                                        order by idx desc

                                    ) as ab
                                cross join
                                    lateral (
                                        select
                                            asset_in,
                                            asset_out,
                                            price_1over0
                                        from (
                                            with
                                                assets as (
                                                    select *
                                                    from
                                                        (

                                                            with
                                                                vec_pade as (
                                                                    select buf
                                                                    from
                                                                        (
                                                                            -- 0. assets,
                                                                            -- 1. pairs,
                                                                            -- 2.
                                                                            -- pool_updates, 3. top_of_block_orders, 4. user_orders
                                                                            with
                                                                                trimmed_input
                                                                                as (
                                                                                    select
                                                                                        1
                                                                                        as next_offset,
                                                                                        varbinary_substring(
                                                                                            seed.txi,
                                                                                            69
                                                                                        )
                                                                                        as next_buf
                                                                                ),
                                                                                -- assets
                                                                                step0 as (
                                                                                    select
                                                                                        len
                                                                                        + 3
                                                                                        +
                                                                                    offset
                                                                                        as next_offset,
                                                                                        varbinary_substring(
                                                                                            next_buf,
                                                                                            offset,
                                                                                            len
                                                                                            + 3
                                                                                        )
                                                                                        as buf,
                                                                                        next_buf
                                                                                    from
                                                                                        (
                                                                                            select
                                                                                                next_offset
                                                                                                as offset,
                                                                                                varbinary_to_integer(
                                                                                                    varbinary_substring(
                                                                                                        next_buf,
                                                                                                        next_offset,
                                                                                                        3
                                                                                                    )
                                                                                                )
                                                                                                as len,
                                                                                                next_buf
                                                                                            from
                                                                                                trimmed_input
                                                                                        )
                                                                                ),
                                                                                -- pairs
                                                                                step1 as (
                                                                                    select
                                                                                        len
                                                                                        + 3
                                                                                        +
                                                                                    offset
                                                                                        as next_offset,
                                                                                        varbinary_substring(
                                                                                            next_buf,
                                                                                            offset,
                                                                                            len
                                                                                            + 3
                                                                                        )
                                                                                        as buf,
                                                                                        next_buf
                                                                                    from
                                                                                        (
                                                                                            select
                                                                                                next_offset
                                                                                                as offset,
                                                                                                varbinary_to_integer(
                                                                                                    varbinary_substring(
                                                                                                        next_buf,
                                                                                                        next_offset,
                                                                                                        3
                                                                                                    )
                                                                                                )
                                                                                                as len,
                                                                                                next_buf
                                                                                            from
                                                                                                step0
                                                                                        )
                                                                                ),
                                                                                -- pool
                                                                                -- updates
                                                                                step2 as (
                                                                                    select
                                                                                        len
                                                                                        + 3
                                                                                        +
                                                                                    offset
                                                                                        as next_offset,
                                                                                        varbinary_substring(
                                                                                            next_buf,
                                                                                            offset,
                                                                                            len
                                                                                            + 3
                                                                                        )
                                                                                        as buf,
                                                                                        next_buf
                                                                                    from
                                                                                        (
                                                                                            select
                                                                                                next_offset
                                                                                                as offset,
                                                                                                varbinary_to_integer(
                                                                                                    varbinary_substring(
                                                                                                        next_buf,
                                                                                                        next_offset,
                                                                                                        3
                                                                                                    )
                                                                                                )
                                                                                                as len,
                                                                                                next_buf
                                                                                            from
                                                                                                step1
                                                                                        )
                                                                                ),
                                                                                -- top of
                                                                                -- block
                                                                                -- orders
                                                                                step3 as (
                                                                                    select
                                                                                        len
                                                                                        + 3
                                                                                        +
                                                                                    offset
                                                                                        as next_offset,
                                                                                        varbinary_substring(
                                                                                            next_buf,
                                                                                            offset,
                                                                                            len
                                                                                            + 3
                                                                                        )
                                                                                        as buf,
                                                                                        next_buf
                                                                                    from
                                                                                        (
                                                                                            select
                                                                                                next_offset
                                                                                                as offset,
                                                                                                varbinary_to_integer(
                                                                                                    varbinary_substring(
                                                                                                        next_buf,
                                                                                                        next_offset,
                                                                                                        3
                                                                                                    )
                                                                                                )
                                                                                                as len,
                                                                                                next_buf
                                                                                            from
                                                                                                step2
                                                                                        )
                                                                                ),
                                                                                -- user
                                                                                -- orders
                                                                                step4 as (
                                                                                    select
                                                                                        len
                                                                                        + 3
                                                                                        +
                                                                                    offset
                                                                                        as next_offset,
                                                                                        varbinary_substring(
                                                                                            next_buf,
                                                                                            offset,
                                                                                            len
                                                                                            + 3
                                                                                        )
                                                                                        as buf,
                                                                                        next_buf
                                                                                    from
                                                                                        (
                                                                                            select
                                                                                                next_offset
                                                                                                as offset,
                                                                                                varbinary_to_integer(
                                                                                                    varbinary_substring(
                                                                                                        next_buf,
                                                                                                        next_offset,
                                                                                                        3
                                                                                                    )
                                                                                                )
                                                                                                as len,
                                                                                                next_buf
                                                                                            from
                                                                                                step3
                                                                                        )
                                                                                )
                                                                            select
                                                                                seed.txi,
                                                                                buf_rec_vs.buf
                                                                                as buf
                                                                            from
                                                                                (
                                                                                    select
                                                                                        t.tx_data
                                                                                        as txi
                                                                                ) as seed
                                                                            cross join
                                                                                lateral (
                                                                                    select
                                                                                        buf
                                                                                    from
                                                                                        step0
                                                                                )
                                                                                as buf_rec_vs

                                                                        )
                                                                )
                                                            select
                                                                bundle_idx,
                                                                token_address,
                                                                save_amount,
                                                                take_amount,
                                                                settle_amount
                                                            from
                                                                (
                                                                    with recursive
                                                                        decode_asset(
                                                                            buf,
                                                                            len,
                                                                            idx,
                                                                            addr,
                                                                            save,
                                                                            take,
                                                                            settle
                                                                        ) as (
                                                                            select
                                                                                varbinary_substring(
                                                                                    buf,
                                                                                    4,
                                                                                    varbinary_length(
                                                                                        buf
                                                                                    )
                                                                                    - 3
                                                                                ),
                                                                                varbinary_to_integer(
                                                                                    varbinary_substring(
                                                                                        buf,
                                                                                        1,
                                                                                        3
                                                                                    )
                                                                                )
                                                                                / 68 as len,
                                                                                0 as idx,
                                                                                cast(
                                                                                    null
                                                                                    as varbinary
                                                                                ) as addr,
                                                                                cast(
                                                                                    0
                                                                                    as uint256
                                                                                ) as save,
                                                                                cast(
                                                                                    0
                                                                                    as uint256
                                                                                ) as take,
                                                                                cast(
                                                                                    0
                                                                                    as uint256
                                                                                ) as settle
                                                                            from vec_pade

                                                                            union all

                                                                            select
                                                                                varbinary_substring(
                                                                                    buf,
                                                                                    69,
                                                                                    varbinary_length(
                                                                                        buf
                                                                                    )
                                                                                    - 68
                                                                                ) as enc,
                                                                                len,
                                                                                idx
                                                                                + 1
                                                                                as new_idx,
                                                                                varbinary_substring(
                                                                                    buf,
                                                                                    1,
                                                                                    20
                                                                                ) as addr,
                                                                                varbinary_to_uint256(
                                                                                    varbinary_substring(
                                                                                        buf,
                                                                                        21,
                                                                                        16
                                                                                    )
                                                                                ) as save,
                                                                                varbinary_to_uint256(
                                                                                    varbinary_substring(
                                                                                        buf,
                                                                                        37,
                                                                                        16
                                                                                    )
                                                                                ) as take,
                                                                                varbinary_to_uint256(
                                                                                    varbinary_substring(
                                                                                        buf,
                                                                                        53,
                                                                                        16
                                                                                    )
                                                                                ) as settle
                                                                            from
                                                                                decode_asset
                                                                            where idx < len
                                                                        )
                                                                    select
                                                                        idx as bundle_idx,
                                                                        addr
                                                                        as token_address,
                                                                        save as save_amount,
                                                                        take as take_amount,
                                                                        settle
                                                                        as settle_amount
                                                                    from decode_asset
                                                                    where idx > 0
                                                                )

                                                        )
                                                ),
                                                pairs as (
                                                    select
                                                        bundle_idx,
                                                        index0,
                                                        index1,
                                                        price_1over0
                                                    from
                                                        (

                                                            with
                                                                vec_pade as (
                                                                    select buf
                                                                    from
                                                                        (
                                                                            -- 0. assets,
                                                                            -- 1. pairs,
                                                                            -- 2.
                                                                            -- pool_updates, 3. top_of_block_orders, 4. user_orders
                                                                            with
                                                                                trimmed_input
                                                                                as (
                                                                                    select
                                                                                        1
                                                                                        as next_offset,
                                                                                        varbinary_substring(
                                                                                            seed.txi,
                                                                                            69
                                                                                        )
                                                                                        as next_buf
                                                                                ),
                                                                                -- assets
                                                                                step0 as (
                                                                                    select
                                                                                        len
                                                                                        + 3
                                                                                        +
                                                                                    offset
                                                                                        as next_offset,
                                                                                        varbinary_substring(
                                                                                            next_buf,
                                                                                            offset,
                                                                                            len
                                                                                            + 3
                                                                                        )
                                                                                        as buf,
                                                                                        next_buf
                                                                                    from
                                                                                        (
                                                                                            select
                                                                                                next_offset
                                                                                                as offset,
                                                                                                varbinary_to_integer(
                                                                                                    varbinary_substring(
                                                                                                        next_buf,
                                                                                                        next_offset,
                                                                                                        3
                                                                                                    )
                                                                                                )
                                                                                                as len,
                                                                                                next_buf
                                                                                            from
                                                                                                trimmed_input
                                                                                        )
                                                                                ),
                                                                                -- pairs
                                                                                step1 as (
                                                                                    select
                                                                                        len
                                                                                        + 3
                                                                                        +
                                                                                    offset
                                                                                        as next_offset,
                                                                                        varbinary_substring(
                                                                                            next_buf,
                                                                                            offset,
                                                                                            len
                                                                                            + 3
                                                                                        )
                                                                                        as buf,
                                                                                        next_buf
                                                                                    from
                                                                                        (
                                                                                            select
                                                                                                next_offset
                                                                                                as offset,
                                                                                                varbinary_to_integer(
                                                                                                    varbinary_substring(
                                                                                                        next_buf,
                                                                                                        next_offset,
                                                                                                        3
                                                                                                    )
                                                                                                )
                                                                                                as len,
                                                                                                next_buf
                                                                                            from
                                                                                                step0
                                                                                        )
                                                                                ),
                                                                                -- pool
                                                                                -- updates
                                                                                step2 as (
                                                                                    select
                                                                                        len
                                                                                        + 3
                                                                                        +
                                                                                    offset
                                                                                        as next_offset,
                                                                                        varbinary_substring(
                                                                                            next_buf,
                                                                                            offset,
                                                                                            len
                                                                                            + 3
                                                                                        )
                                                                                        as buf,
                                                                                        next_buf
                                                                                    from
                                                                                        (
                                                                                            select
                                                                                                next_offset
                                                                                                as offset,
                                                                                                varbinary_to_integer(
                                                                                                    varbinary_substring(
                                                                                                        next_buf,
                                                                                                        next_offset,
                                                                                                        3
                                                                                                    )
                                                                                                )
                                                                                                as len,
                                                                                                next_buf
                                                                                            from
                                                                                                step1
                                                                                        )
                                                                                ),
                                                                                -- top of
                                                                                -- block
                                                                                -- orders
                                                                                step3 as (
                                                                                    select
                                                                                        len
                                                                                        + 3
                                                                                        +
                                                                                    offset
                                                                                        as next_offset,
                                                                                        varbinary_substring(
                                                                                            next_buf,
                                                                                            offset,
                                                                                            len
                                                                                            + 3
                                                                                        )
                                                                                        as buf,
                                                                                        next_buf
                                                                                    from
                                                                                        (
                                                                                            select
                                                                                                next_offset
                                                                                                as offset,
                                                                                                varbinary_to_integer(
                                                                                                    varbinary_substring(
                                                                                                        next_buf,
                                                                                                        next_offset,
                                                                                                        3
                                                                                                    )
                                                                                                )
                                                                                                as len,
                                                                                                next_buf
                                                                                            from
                                                                                                step2
                                                                                        )
                                                                                ),
                                                                                -- user
                                                                                -- orders
                                                                                step4 as (
                                                                                    select
                                                                                        len
                                                                                        + 3
                                                                                        +
                                                                                    offset
                                                                                        as next_offset,
                                                                                        varbinary_substring(
                                                                                            next_buf,
                                                                                            offset,
                                                                                            len
                                                                                            + 3
                                                                                        )
                                                                                        as buf,
                                                                                        next_buf
                                                                                    from
                                                                                        (
                                                                                            select
                                                                                                next_offset
                                                                                                as offset,
                                                                                                varbinary_to_integer(
                                                                                                    varbinary_substring(
                                                                                                        next_buf,
                                                                                                        next_offset,
                                                                                                        3
                                                                                                    )
                                                                                                )
                                                                                                as len,
                                                                                                next_buf
                                                                                            from
                                                                                                step3
                                                                                        )
                                                                                )
                                                                            select
                                                                                seed.txi,
                                                                                buf_rec_vs.buf
                                                                                as buf
                                                                            from
                                                                                (
                                                                                    select
                                                                                        t.tx_data
                                                                                        as txi
                                                                                ) as seed
                                                                            cross join
                                                                                lateral (
                                                                                    select
                                                                                        buf
                                                                                    from
                                                                                        step1
                                                                                )
                                                                                as buf_rec_vs

                                                                        )
                                                                )
                                                            select
                                                                bundle_idx,
                                                                index0,
                                                                index1,
                                                                store_index,
                                                                price_1over0
                                                            from
                                                                (
                                                                    with recursive
                                                                        decode_pair(
                                                                            buf,
                                                                            len,
                                                                            idx,
                                                                            index0,
                                                                            index1,
                                                                            store_index,
                                                                            price_1over0
                                                                        ) as (
                                                                            select
                                                                                varbinary_substring(
                                                                                    buf,
                                                                                    4,
                                                                                    varbinary_length(
                                                                                        buf
                                                                                    )
                                                                                    - 3
                                                                                ),
                                                                                varbinary_to_integer(
                                                                                    varbinary_substring(
                                                                                        buf,
                                                                                        1,
                                                                                        3
                                                                                    )
                                                                                )
                                                                                / 38 as len,
                                                                                0 as idx,
                                                                                0 as index0,
                                                                                0 as index1,
                                                                                0
                                                                                as store_index,
                                                                                cast(
                                                                                    0
                                                                                    as uint256
                                                                                )
                                                                                as price_1over0
                                                                            from vec_pade

                                                                            union all

                                                                            select
                                                                                varbinary_substring(
                                                                                    buf,
                                                                                    39,
                                                                                    varbinary_length(
                                                                                        buf
                                                                                    )
                                                                                    - 38
                                                                                ) as enc,
                                                                                len,
                                                                                idx
                                                                                + 1
                                                                                as new_idx,
                                                                                varbinary_to_integer(
                                                                                    varbinary_substring(
                                                                                        buf,
                                                                                        1,
                                                                                        2
                                                                                    )
                                                                                ) as index0,
                                                                                varbinary_to_integer(
                                                                                    varbinary_substring(
                                                                                        buf,
                                                                                        3,
                                                                                        2
                                                                                    )
                                                                                ) as index1,
                                                                                varbinary_to_integer(
                                                                                    varbinary_substring(
                                                                                        buf,
                                                                                        5,
                                                                                        2
                                                                                    )
                                                                                )
                                                                                as store_index,
                                                                                varbinary_to_uint256(
                                                                                    varbinary_substring(
                                                                                        buf,
                                                                                        7,
                                                                                        32
                                                                                    )
                                                                                )
                                                                                as price_1over0
                                                                            from decode_pair
                                                                            where idx < len
                                                                        )
                                                                    select
                                                                        idx as bundle_idx,
                                                                        index0,
                                                                        index1,
                                                                        store_index,
                                                                        price_1over0
                                                                    from decode_pair
                                                                    where idx > 0
                                                                )

                                                        )
                                                ),
                                                _asset_in as (
                                                    select
                                                        p.price_1over0,
                                                        a.token_address as asset_in,
                                                        ab.pairs_index,
                                                        ab.zero_for_1
                                                    from assets as a
                                                    cross join pairs as p
                                                    where
                                                        a.bundle_idx = p.index0
                                                        and p.bundle_idx = ab.pairs_index
                                                ),
                                                _asset_out as (
                                                    select 
                                                        a.token_address as asset_out,
                                                        ab.pairs_index
                                                    from assets as a
                                                    cross join pairs as p
                                                    where
                                                        a.bundle_idx = p.index1
                                                        and p.bundle_idx = ab.pairs_index
                                                ),
                                                zfo_assets as (
                                                    select
                                                        i.price_1over0,
                                                        if(
                                                            i.zero_for_1,
                                                            array[i.asset_in, o.asset_out],
                                                            array[o.asset_out, i.asset_in]
                                                        ) as zfo_sorted_assets
                                                    from _asset_in i
                                                    inner join _asset_out o on i.pairs_index = o.pairs_index
                                                )
                                            select
                                                zfo_sorted_assets[1] as asset_in,
                                                zfo_sorted_assets[2] as asset_out,
                                                price_1over0
                                            from zfo_assets
                                        ) x
                                    ) as asts
                            ) as tob_vs

                    ) as p
            )
        select
            *
        from tob_orders

    )

select *
from dexs
