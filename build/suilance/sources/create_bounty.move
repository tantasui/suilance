#[allow(duplicate_alias)]
module suilance::create_bounty {
        
        use sui::coin::{Self, Coin};
        use sui::object::{Self, UID};
        use sui::balance::{Self, Balance};
        use std::string::{Self, String};
        use sui::sui::SUI;

    const EInvalidPrizeDistribution: u64 = 0;
    const EInvalidPositionSequence: u64 = 1;
    const EInsufficientFunds: u64 = 2;
    public struct Prize has store, copy, drop {
        position: u64,
        reward: u64,
    }
    public struct OwnerCap has key{
        id: UID
    }
    public struct Bounty has key, store {
        id: UID,
        title: String,
        description: String,
        creator: address,
        prize: vector<Prize>,
        active: bool,
        duration: u64
    }



    public struct Escrow has key, store {
        id: UID,
        balance: Balance<SUI>
    }

    fun init(ctx: &mut TxContext) {
        transfer::share_object(
            Escrow {
                id: object::new(ctx),
                balance: balance::zero()
            }
        );
    }
    #[allow(unused_variable)]
    
    public fun create_bounty(title: String, description: String, prize: vector<Prize>, duration: u64, ctx: &mut TxContext) {
        let sender = tx_context::sender(ctx);
        
        let bounty = Bounty {
            id: object::new(ctx),
            title: title,
            description: description,
            creator: sender,
            prize: prize,
            active: true,
            duration: duration
        };

        transfer::share_object(bounty)
    }
    public fun deposit(escrow: &mut Escrow, token: Coin<SUI>, prize: vector<Prize>, ) {
        let len = vector::length(&prize);
        let mut total: u64 = 0;
        let mut i: u64 = 0;
        while (i < len - 1) {
            let current_prize = *vector::borrow(&prize, i);
            let next_prize = *vector::borrow(&prize, i + 1);
            assert!(current_prize.reward > next_prize.reward, EInvalidPrizeDistribution);
            assert!(current_prize.position + 1 == next_prize.position, EInvalidPositionSequence);
            i = i + 1;
        };
        i = 0;
        let value = coin::value(&token);
        while (i < len) {
            let current_prize = *vector::borrow(&prize, i);
            total = total + current_prize.reward;
            i = i + 1;
        };
        assert!(total == value, EInsufficientFunds);
        balance::join(&mut escrow.balance, coin::into_balance(token));

    
    }


    // Add these helper functions needed for testing
    public fun get_creator(bounty: &Bounty): address {
        bounty.creator
    }

    public fun is_active(bounty: &Bounty): bool {
        bounty.active
    }

    public fun get_escrow_balance(escrow: &Escrow): &Balance<SUI> {
        &escrow.balance
    }

    #[test_only]
    // Helper to create a prize vector for testing
    fun create_test_prizes(): vector<Prize> {
        let mut prizes = vector::empty();
        vector::push_back(&mut prizes, Prize { position: 1, reward: 1000 });
        vector::push_back(&mut prizes, Prize { position: 2, reward: 500 });
        prizes
    }

    #[test]
    fun test_create_bounty_success() {
        use sui::test_scenario::{Self as test, next_tx, ctx};
        
        let mut scenario = test::begin(@0xA);
        let test_prizes = create_test_prizes();
        
        // Create bounty
        next_tx(&mut scenario, @0xA);
        {
            create_bounty(
                string::utf8(b"Test Bounty"),
                string::utf8(b"Test Description"),
                test_prizes,
                86400, // 1 day duration
                ctx(&mut scenario)
            );
        };

        // Verify bounty was created and shared
        next_tx(&mut scenario, @0xA);
        {
            let bounty = test::take_shared<Bounty>(&scenario);
            assert!(get_creator(&bounty) == @0xA, 1);
            assert!(is_active(&bounty) == true, 2);
            test::return_shared(bounty);
        };
        
        test::end(scenario);
    }

    #[test]
    fun test_deposit_success() {
        use sui::test_scenario::{Self as test, next_tx, ctx};
        
        let mut scenario = test::begin(@0xA);
        let test_prizes = create_test_prizes();
        
        // Create bounty and escrow
        next_tx(&mut scenario, @0xA);
        {
            // Initialize module which creates shared escrow
            init(ctx(&mut scenario));
            
            create_bounty(
                string::utf8(b"Test Bounty"),
                string::utf8(b"Test Description"),
                test_prizes,
                86400,
                ctx(&mut scenario)
            );
        };

        // Mint test coins and deposit
        next_tx(&mut scenario, @0xA);
        {
            let mut bounty = test::take_shared<Bounty>(&scenario);
            let mut escrow = test::take_shared<Escrow>(&scenario);
            
            // Mint exactly 1500 (1000 + 500) tokens for the prizes
            let coin = coin::mint_for_testing<SUI>(1500, ctx(&mut scenario));
            
            deposit(
                &mut escrow,
                coin,
                test_prizes
            );

            // Verify escrow balance
            assert!(balance::value(get_escrow_balance(&escrow)) == 1500, 3);
            
            test::return_shared(bounty);
            test::return_shared(escrow);
        };
        
        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = EInsufficientFunds)]
    fun test_deposit_insufficient_funds() {
        use sui::test_scenario::{Self as test, next_tx, ctx};
        
        let mut scenario = test::begin(@0xA);
        let test_prizes = create_test_prizes();
        
        // Create bounty and escrow
        next_tx(&mut scenario, @0xA);
        {
            init(ctx(&mut scenario));
            create_bounty(
                string::utf8(b"Test Bounty"),
                string::utf8(b"Test Description"),
                test_prizes,
                86400,
                ctx(&mut scenario)
            );
        };

        // Try to deposit insufficient funds
        next_tx(&mut scenario, @0xA);
        {
            let mut bounty = test::take_shared<Bounty>(&scenario);
            let mut escrow = test::take_shared<Escrow>(&scenario);
            
            // Mint only 1000 tokens when 1500 are needed
            let coin = coin::mint_for_testing<SUI>(1000, ctx(&mut scenario));
            
            // This should fail
            deposit(
                &mut escrow,
                coin,
                test_prizes,
            );
            
            test::return_shared(bounty);
            test::return_shared(escrow);
        };
        
        test::end(scenario);
    }
}


    
   