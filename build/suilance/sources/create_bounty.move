#[allow(lint(coin_field))]
module suilance::create_bounty {
    
    use sui::coin::{Self, Coin};
    use sui::sui::SUI;
   
    
    public struct Bounty has key, store {
        id: UID,
        creator: address,
        total_prize: u64,
        prize_amount: vector<u64>,
        payment: Coin<SUI>
    }
    
    public fun create_bounty(prize_amount: vector<u64>, payment: Coin<SUI>, ctx: &mut TxContext) {
        let mut total: u64 = 0;
        let mut i = 0;
        let len = vector::length(&prize_amount);
        
        while (i < len) {
            let amount = *vector::borrow(&prize_amount, i);
            total = total + amount;
            i = i + 1;
        };
        
        assert!(coin::value(&payment) == total, 0);
        
        let bounty = Bounty {
            id: object::new(ctx),
            creator: tx_context::sender(ctx),
            total_prize: total,
            prize_amount,
            payment
        };
        
        transfer::share_object(bounty)
    }

    // Getter functions for testing
    public fun creator(bounty: &Bounty): address {
        bounty.creator
    }

    public fun total_prize(bounty: &Bounty): u64 {
        bounty.total_prize
    }

    public fun prize_amount(bounty: &Bounty): &vector<u64> {
        &bounty.prize_amount
    }

    #[test_only]
    use sui::test_scenario::{Self as test, next_tx};
    #[test_only]
    use sui::coin::mint_for_testing;

    #[test]
    fun test_successful_bounty_creation() {
        let owner = @0xA;
        let mut scenario = test::begin(owner);
        
        // First transaction: Create bounty
        next_tx(&mut scenario, owner); 
        {
            let prize_amounts = vector[100, 50, 25];
            let payment = mint_for_testing<SUI>(175, test::ctx(&mut scenario));
            create_bounty(prize_amounts, payment, test::ctx(&mut scenario));
        };
        
        // Second transaction: Verify bounty
        next_tx(&mut scenario, owner); 
        {
            let bounty = test::take_shared<Bounty>(&scenario);
            assert!(creator(&bounty) == owner, 0);
            assert!(total_prize(&bounty) == 175, 1);
            let amounts = prize_amount(&bounty);
            assert!(*vector::borrow(amounts, 0) == 100, 2);
            assert!(*vector::borrow(amounts, 1) == 50, 3);
            assert!(*vector::borrow(amounts, 2) == 25, 4);
            test::return_shared(bounty);
        };
        
        test::end(scenario);
    }

    #[test]
    #[expected_failure(abort_code = 0)]
    fun test_insufficient_payment() {
        let owner = @0xA;
        let mut scenario = test::begin(owner);
        
        next_tx(&mut scenario, owner); 
        {
            let prize_amounts = vector[100, 50, 25]; // Total should be 175
            let payment = mint_for_testing<SUI>(150, test::ctx(&mut scenario)); // Less than required
            create_bounty(prize_amounts, payment, test::ctx(&mut scenario));
        };
        
        test::end(scenario);
    }
}