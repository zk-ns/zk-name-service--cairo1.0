use starknet::ContractAddress;

#[abi]
trait IERC20 {
    #[view]
    fn name() -> felt252;

    #[view]
    fn symbol() -> felt252;

    #[view]
    fn decimals() -> u8;

    #[view]
    fn total_supply() -> u256;

    #[view]
    fn balance_of(account: ContractAddress) -> u256;

    #[view]
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256;

    #[external]
    fn transfer(recipient: ContractAddress, amount: u256) -> bool;

    #[external]
    fn transferFrom(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;

    #[external]
    fn approve(spender: ContractAddress, amount: u256) -> bool;
}

#[abi]
trait NGTToken {

    #[view]
    fn decimals() -> u8;

    #[view]
    fn total_supply() -> u256;

    #[external]
    fn mint(addr: ContractAddress, amount: u256);

    #[view]
    fn balance_of(account: ContractAddress) -> u256;

    #[view]
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256;

    #[external]
    fn transfer(recipient: ContractAddress, amount: u256) -> bool;

    #[external]
    fn transferFrom(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;

    #[external]
    fn approve(spender: ContractAddress, amount: u256) -> bool;
}



#[contract]
mod StarknetNS {
    use starknet::ContractAddress;
    use starknet::contract_address_const;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::get_block_timestamp;
    use array::ArrayTrait;
    use zeroable::Zeroable;
    use super::IERC20DispatcherTrait;
    use super::IERC20Dispatcher;
    use super::NGTTokenDispatcherTrait;
    use super::NGTTokenDispatcher;
    use traits::Into;
    use traits::TryInto;
    use option::OptionTrait;
    

    struct Storage {
        myns: LegacyMap::<ContractAddress, felt252>,
        ns_to_address: LegacyMap::<felt252, ContractAddress>,
        ns_to_time: LegacyMap::<felt252, u64>,
        owner: ContractAddress,
        eth20_address: ContractAddress,
        ngttoken_address: ContractAddress,
        price: u256,
        base_mint: u256,
        my_recommend: LegacyMap::<ContractAddress, ContractAddress>, // who invite me
        my_community: LegacyMap::<ContractAddress, ContractAddress>, // who is my Community Leader
        recommend_effect: LegacyMap::<ContractAddress, bool>, 
        my_reward: LegacyMap::<ContractAddress, u256>, 
        leader_price: u256,
        total_ns: u256,
        allow_renew: bool,
        allow_transfer: bool,
        renew_price: u256,
    }
    
    #[event]
    fn RegisterInfo(from_address: ContractAddress, domain: felt252, year: u64, registerDate: u64) {}

     #[event]
    fn RenewInfo(from_address: ContractAddress, domain: felt252, year: u64, renewDate: u64) {}

    #[event]
    fn InviteInfo(original_address: ContractAddress, invite_address: ContractAddress, time: u64) {}

    #[event]
    fn CommunityInfo(community_address: ContractAddress, member_address: ContractAddress, time: u64) {}

    #[event]
    fn InviteEarnInfo(from_address: ContractAddress, earn_address: ContractAddress, kind: u8, amount: u256, time: u64) {}

    #[event]
    fn CommunityEarnInfo(from_address: ContractAddress, earn_address: ContractAddress, kind: u8, amount: u256, time: u64) {}

    

    #[constructor]
    fn constructor(_owner: ContractAddress){
        owner::write(_owner);
        price::write(1000000000000000);
        renew_price::write(1000000000000000);
        leader_price::write(10000000000000000);
        base_mint::write(1000000000000000000000);
        total_ns::write(0);
        recommend_effect::write(_owner, true);
        my_recommend::write(_owner, _owner);
        my_community::write(_owner, _owner);
        allow_renew::write(false);
        allow_transfer::write(false);
    }

    #[external]
    fn change_price(_price: u256){
       let caller: ContractAddress = get_caller_address();
       assert(owner::read() == caller, 'not owner');
       price::write(_price);
    }

    #[external]
    fn change_renew_price(_price: u256){
       let caller: ContractAddress = get_caller_address();
       assert(owner::read() == caller, 'not owner');
       renew_price::write(_price);
    }

    #[external]
    fn set_allow_transfer(_allow_transfer: bool){
       let caller: ContractAddress = get_caller_address();
       assert(owner::read() == caller, 'not owner');
       allow_transfer::write(_allow_transfer);
    }

    #[external]
    fn set_allow_renew(_allow_renew: bool){
       let caller: ContractAddress = get_caller_address();
       assert(owner::read() == caller, 'not owner');
       allow_renew::write(_allow_renew);
    }

    #[external]
    fn change_base_mint(_base_mint: u256){
       let caller: ContractAddress = get_caller_address();
       assert(owner::read() == caller, 'not owner');
       base_mint::write(_base_mint);
    }

    #[external]
    fn change_owner(_owner: ContractAddress){
       let caller: ContractAddress = get_caller_address();
       assert(owner::read() == caller, 'not owner');
       owner::write(_owner);
    }

    #[external]
    fn set_contract_address( _ethaddress: ContractAddress, _ngttokenaddress: ContractAddress){
       let caller: ContractAddress = get_caller_address();
       assert(owner::read() == caller, 'not owner');
       eth20_address::write(_ethaddress);
       ngttoken_address::write(_ngttokenaddress);
    }

    #[external]
    fn claim(_amount: u256){
       let caller: ContractAddress = get_caller_address();
       assert(owner::read() == caller, 'not owner');
       IERC20Dispatcher { contract_address: eth20_address::read() }.transfer(caller, _amount);
    }

    #[external]
    fn claim_ngttoken(recommend: ContractAddress){
       
       let caller: ContractAddress = get_caller_address();
       let _amount = my_reward::read(caller);
       assert(_amount > 0, 'balance not enough');
       let _my_recommend = my_recommend::read(caller);
       let _my_community = my_community::read(caller);
       if(_my_recommend.is_zero()){
          assert(recommend_effect::read(recommend), 'recommend not allow');
          my_recommend::write(caller, recommend);
          InviteInfo(recommend, caller, get_block_timestamp());
       }
       if(_my_community.is_zero()){
          if(my_community::read(recommend).is_zero()){
             my_community::write(caller, get_contract_address());
          }else{
             my_community::write(caller, my_community::read(recommend));
             CommunityInfo(my_community::read(recommend), caller, get_block_timestamp());
          }
       }
       if(!recommend_effect::read(caller)){
           recommend_effect::write(caller, true);
       }
       let mut _profit_amount: u128 = (_amount.try_into().unwrap()).try_into().unwrap();
       _profit_amount = _profit_amount * 10 / 100;
       let profit_amount: felt252 = _profit_amount.into();
       let profit_amount_: u256 = profit_amount.into();

       NGTTokenDispatcher { contract_address: ngttoken_address::read() }.mint(my_recommend::read(caller), profit_amount_);
       NGTTokenDispatcher { contract_address: ngttoken_address::read() }.mint(my_community::read(caller), profit_amount_);
       NGTTokenDispatcher { contract_address: ngttoken_address::read() }.mint(caller, (_amount - 2 * profit_amount_));
       my_reward::write(caller, 0);
       //event
       InviteEarnInfo(caller, my_recommend::read(caller), 1, profit_amount_, get_block_timestamp());
       CommunityEarnInfo(caller, my_community::read(caller), 1, profit_amount_, get_block_timestamp());
    }

    #[external]
    fn become_community_leader(){
       let caller: ContractAddress = get_caller_address();
       assert(recommend_effect::read(caller), 'not effect address');
       assert((!my_community::read(caller).is_zero()) & (!my_recommend::read(caller).is_zero()), 'claim token first');
       assert(my_community::read(caller) != caller, 'already leader');

       let _amount = leader_price::read();

       let mut _profit_amount: u128 = (_amount.try_into().unwrap()).try_into().unwrap();
       _profit_amount = _profit_amount * 10 / 100;
       let profit_amount: felt252 = _profit_amount.into();
       let profit_amount_: u256 = profit_amount.into();

       IERC20Dispatcher { contract_address: eth20_address::read() }.transferFrom(caller, get_contract_address(), (_amount - 2 * profit_amount_));
       IERC20Dispatcher { contract_address: eth20_address::read() }.transferFrom(caller, my_community::read(caller), profit_amount_);
       IERC20Dispatcher { contract_address: eth20_address::read() }.transferFrom(caller, my_recommend::read(caller), profit_amount_);
       my_community::write(caller, caller);
       //event
       InviteEarnInfo(caller, my_recommend::read(caller), 2, profit_amount_, get_block_timestamp());
       CommunityEarnInfo(caller, my_community::read(caller), 2, profit_amount_, get_block_timestamp());
    }

    #[external]
    fn set_ns(str: felt252, _year: u256) {

        assert(_year >= 1, 'year not allow');
        assert(_year <= 5, 'year not allow');
 
        let (_price, multiple) = computer_price(str, _year, price::read());
        let result_str: felt252 = add_suffix(str);
        
        let caller: ContractAddress = get_caller_address();
        let thisaddress: ContractAddress = get_contract_address();
        IERC20Dispatcher { contract_address: eth20_address::read() }.transferFrom(caller, thisaddress, _price);
        let _address: ContractAddress = ns_to_address::read(result_str);
        let _str: felt252 = myns::read(caller);
        assert(_address.is_zero(), 'ns already register');
        assert(_str == 0, 'address already register');
        ns_to_address::write(result_str, caller);
        let years: u64 = (_year.try_into().unwrap()).try_into().unwrap();
        ns_to_time::write(result_str, (get_block_timestamp() + years*365*24*3600)); //for mainnet
        // ns_to_time::write(result_str, (get_block_timestamp() + years*1*1*60)); //for test
        myns::write(caller, result_str);
        my_reward::write(caller, my_reward::read(caller) + multiple * base_mint::read());
        total_ns::write(total_ns::read() + 1);
        RegisterInfo(caller, result_str, years, get_block_timestamp());
    }

    #[external]
    fn renew_ns(str: felt252, _year: u256) {
        assert(allow_renew::read(), 'not allow');
        assert(_year >= 1, 'year not allow');
        assert(_year <= 5, 'year not allow');
 
        let (_price, multiple) = computer_price(str, _year, renew_price::read());
        let result_str: felt252 = add_suffix(str);
        
        let caller: ContractAddress = get_caller_address();
        let thisaddress: ContractAddress = get_contract_address();
        IERC20Dispatcher { contract_address: eth20_address::read() }.transferFrom(caller, thisaddress, _price);
        let _address: ContractAddress = ns_to_address::read(result_str);
        assert(_address == caller, 'not belong');
        let _time = ns_to_time::read(result_str);
        assert(_time > get_block_timestamp() & (_time - 30 * 24 * 3600) < get_block_timestamp(), 'time not allow'); //for mainnet
        // assert(_time > get_block_timestamp() & (_time - 1 * 1 * 1800) < get_block_timestamp(), 'time not allow');//for test
        let years: u64 = (_year.try_into().unwrap()).try_into().unwrap();
        ns_to_time::write(result_str, (ns_to_time::read(result_str) + years*365*24*3600)); //for mainnet
        // ns_to_time::write(result_str, (ns_to_time::read(result_str) + years*1*1*3600)); //for test
        
        RenewInfo(caller, result_str, years, get_block_timestamp());
    }

    #[external]
    fn tranferZKns(str: felt252, recev: ContractAddress){
        assert(allow_transfer::read(), 'not allow');
        let caller: ContractAddress = get_caller_address();
        assert(ns_to_address::read(str) == caller, 'not belong');
        ns_to_address::write(str, recev);
        if(myns::read(caller) == str){
           myns::write(caller, 0);
        }
    }

    #[external]
    fn resolving(str: felt252){
        assert(allow_transfer::read(), 'not allow');
        let caller: ContractAddress = get_caller_address();
        assert(ns_to_address::read(str) == caller, 'not belong');
        myns::write(caller, str);
    }

    #[external]
    fn cancle_ns(str: felt252){
       let caller: ContractAddress = get_caller_address();
       assert(owner::read() == caller, 'not owner');
       let expire: u64 = ns_to_time::read(str);
       assert(expire > 0, 'wrong str');
       let now: u64 = get_block_timestamp();
       assert(now >= expire, 'time not yet');
       ns_to_time::write(str, 0);
       let addr: ContractAddress = ns_to_address::read(str);
       myns::write(addr, 0);
       ns_to_address::write(str, contract_address_const::<0>());
       if(total_ns::read() > 0){
          total_ns::write(total_ns::read() - 1);
       }
    }

    #[view]
    fn computer_price(str: felt252, _year: u256, nsprice: u256) -> (u256, u256) { 
        let mut _price: u256 = nsprice * _year;
        let len: u64 = get_amount_of_chars(1, 1, str);
        let mut multiple: u256 = _year;
        assert(len >= 2, 'chars at least 2');
        if(len < 3){
            _price = _price * 5;
            multiple = multiple * 5;
        }else if(len == 3){
            _price = _price * 4;
            multiple = multiple * 4;
        }else if(len == 4){
            _price = _price * 3;
            multiple = multiple * 3;
        }else if(len == 5){
            _price = _price * 2;
            multiple = multiple * 2;
        }
        return (_price, multiple);
    }
    
    #[view]
    fn get_amount_of_chars(len: u64, num: u256, str: felt252) -> u64 { 
        
        let str_new: u256 = str.into();
        if (num * 255 >= str_new) {
            return len;
        }else if (len > 5){
            return len;
        }else{
            let _num = num * 255;
            let _len = len + 1;
            let next = get_amount_of_chars(_len, _num, str);
            return next;
        } 
    }


    #[view]
    fn add_suffix(str: felt252) -> felt252 { 
        let str_new: u256 = str.into();
        let add_point = str_new * 256 + 46;
        let add_s = add_point * 256 + 115;
        let add_t = add_s * 256 + 116;
        let add_a = add_t * 256 + 97;
        let add_r = add_a * 256 + 114;
        let add_k = add_r * 256 + 107;
        let _result: felt252 = add_k.try_into().unwrap();
        return _result;
    }


    #[view]
    fn get_address(str: felt252) -> ContractAddress {
        ns_to_address::read(str)
    }

    #[view]
    fn get_reward(_address: ContractAddress) -> u256 {
        my_reward::read(_address)
    }

    #[view]
    fn get_ns_time(str: felt252) -> u64 {
        ns_to_time::read(str)
    }

    #[view]
    fn get_ns(_address: ContractAddress) -> felt252 {
        myns::read(_address)
    }

    #[view]
    fn check_recommend_effect(addrs: ContractAddress) -> bool {
        return recommend_effect::read(addrs);
    }

    #[view]
    fn get_my_community(addrs: ContractAddress) -> ContractAddress{
        return my_community::read(addrs);
    }

    #[view]
    fn get_my_recommend(addrs: ContractAddress) -> ContractAddress{
        return my_recommend::read(addrs);
    }

    #[view]
    fn get_total_ns() -> u256{
        return total_ns::read();
    }

}
