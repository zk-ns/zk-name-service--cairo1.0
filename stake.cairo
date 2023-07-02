use starknet::ContractAddress;
use starknet::StorageAccess;
use starknet::StorageBaseAddress;
use starknet::SyscallResult;
use starknet::storage_read_syscall;
use starknet::storage_write_syscall;
use starknet::storage_address_from_base_and_offset;
use traits::Into;
use traits::TryInto;
use option::OptionTrait;

#[derive(Drop, Serde)]
struct OrderInfo {
    orderindex: u64,
    seedmoney: u256,
    kinds: u8,
    starttime: u64,
}

impl OrderInfoStorageAccess of StorageAccess::<OrderInfo> {
    fn read(address_domain: u32, base: StorageBaseAddress) -> SyscallResult::<OrderInfo> {
        Result::Ok(
            OrderInfo {
                orderindex: storage_read_syscall(
                    address_domain, storage_address_from_base_and_offset(base, 0_u8)
                )?.try_into().unwrap(),
                seedmoney: storage_read_syscall(
                    address_domain, storage_address_from_base_and_offset(base, 1_u8)
                )?.into(),
                kinds: storage_read_syscall(
                    address_domain, storage_address_from_base_and_offset(base, 2_u8)
                )?.try_into().unwrap(),
                starttime: storage_read_syscall(
                    address_domain, storage_address_from_base_and_offset(base, 3_u8)
                )?.try_into().unwrap(),
            }
        )
    }

    fn write(address_domain: u32, base: StorageBaseAddress, value: OrderInfo) -> SyscallResult::<()> {
        storage_write_syscall(
            address_domain, storage_address_from_base_and_offset(base, 0_u8), value.orderindex.into()
        )?;
        storage_write_syscall(
            address_domain, storage_address_from_base_and_offset(base, 1_u8), value.seedmoney.try_into().unwrap()
        )?;
        storage_write_syscall(
            address_domain, storage_address_from_base_and_offset(base, 2_u8), value.kinds.into()
        )?;
        storage_write_syscall(
            address_domain, storage_address_from_base_and_offset(base, 3_u8), value.starttime.into()
        )
    }
}

#[abi]
trait NGTToken {

    #[view]
    fn decimals() -> u8;

    #[view]
    fn total_supply() -> u256;

    #[external]
    fn mint(addr: ContractAddress, amount: u256);

    #[external]
    fn poolMint(addr: ContractAddress, amount: u256);

    #[view]
    fn balance_of(account: ContractAddress) -> u256;

    #[view]
    fn allowance(owner: ContractAddress, spender: ContractAddress) -> u256;

    #[external]
    fn transfer(recipient: ContractAddress, amount: u256) -> bool;

    #[external]
    fn transfer_from(sender: ContractAddress, recipient: ContractAddress, amount: u256) -> bool;

    #[external]
    fn approve(spender: ContractAddress, amount: u256) -> bool;
}


#[contract]
mod Stake {
    use starknet::ContractAddress;
    use starknet::contract_address_const;
    use starknet::get_caller_address;
    use starknet::get_contract_address;
    use starknet::get_block_timestamp;
    use array::ArrayTrait;
    use zeroable::Zeroable;
    use super::NGTTokenDispatcherTrait;
    use super::NGTTokenDispatcher;
    use traits::Into;
    use traits::TryInto;
    use option::OptionTrait;
    use super::OrderInfo;
    

    struct Storage {
        address_to_seedmoney: LegacyMap::<(ContractAddress, u64), u256>,
        address_to_kinds: LegacyMap::<(ContractAddress, u64), u8>,
        address_to_starttime: LegacyMap::<(ContractAddress, u64), u64>,
        address_to_index: LegacyMap::<ContractAddress, u64>,
        ngttoken_address: ContractAddress,
        owner: ContractAddress,
    }
    
    #[constructor]
    fn constructor(_owner: ContractAddress){
        owner::write(_owner);
    }

    #[external]
    fn set_token_address(_ngttokenaddress: ContractAddress){
        let caller: ContractAddress = get_caller_address();
        assert(owner::read() == caller, 'not owner');
        ngttoken_address::write(_ngttokenaddress);
    }

    #[external]
    fn make_order(amount: u256, kinds: u8){
       assert(kinds ==1 | kinds == 2 | kinds == 3, 'kinds not accept');
       let caller: ContractAddress = get_caller_address();
       NGTTokenDispatcher { contract_address: ngttoken_address::read() }.transfer_from(caller, get_contract_address(), amount);
       let mut _index = address_to_index::read(caller); 
       _index = _index + 1;
       address_to_seedmoney::write((caller, _index), amount);
       address_to_kinds::write((caller, _index), kinds);
       address_to_starttime::write((caller, _index), get_block_timestamp());
       address_to_index::write(caller, _index);
    }

    #[external]
    fn claim_order(_index: u64){
       let caller: ContractAddress = get_caller_address();
       assert(_index > 0, 'index not allow');
       assert(_index <= address_to_index::read(caller), 'index not allow');
       let kinds = address_to_kinds::read((caller, _index));
       assert(kinds ==1 | kinds == 2 | kinds == 3, 'kinds not accept');
       //for mainnet
       let FIRSTDIFF: u64 = 7 * 24 * 3600;
       let SECONDDIFF: u64 = 14 * 24 * 3600;
       let THIRDDIFF: u64 = 30 * 24 * 3600;
       //for test
    //    let FIRSTDIFF: u64 = 1 * 1 * 360;
    //    let SECONDDIFF: u64 = 1 * 2 * 360;
    //    let THIRDDIFF: u64 = 1 * 3 * 360;

       let starttime = address_to_starttime::read((caller, _index));
       let seedmoney = address_to_seedmoney::read((caller, _index));
       let _seedmoney: u128 = (seedmoney.try_into().unwrap()).try_into().unwrap();
       if(kinds == 1){
          if(get_block_timestamp() - starttime >= FIRSTDIFF){
             NGTTokenDispatcher { contract_address: ngttoken_address::read() }.transfer(caller, seedmoney);
             let _profit_amount = _seedmoney * 3 / 100;
             let profit_amount: felt252 = _profit_amount.into();
             let profit_amount_: u256 = profit_amount.into();
             NGTTokenDispatcher { contract_address: ngttoken_address::read() }.poolMint(caller, profit_amount_);
          }else{
             let after_amount = _seedmoney * 97 / 100;
             let _after_amount: felt252 = after_amount.into();
             let after_amount_: u256 = _after_amount.into();
             NGTTokenDispatcher { contract_address: ngttoken_address::read() }.transfer(caller, after_amount_);
          }
       }else if(kinds == 2){
          if(get_block_timestamp() - starttime >= SECONDDIFF){
             NGTTokenDispatcher { contract_address: ngttoken_address::read() }.transfer(caller, seedmoney);
             let _profit_amount = _seedmoney * 5 / 100;
             let profit_amount: felt252 = _profit_amount.into();
             let profit_amount_: u256 = profit_amount.into();
             NGTTokenDispatcher { contract_address: ngttoken_address::read() }.poolMint(caller, profit_amount_);
          }else{
             let after_amount = _seedmoney * 95 / 100;
             let _after_amount: felt252 = after_amount.into();
             let after_amount_: u256 = _after_amount.into();
             NGTTokenDispatcher { contract_address: ngttoken_address::read() }.transfer(caller, after_amount_);
          }
       }else if(kinds == 3){
          if(get_block_timestamp() - starttime >= THIRDDIFF){
             NGTTokenDispatcher { contract_address: ngttoken_address::read() }.transfer(caller, seedmoney);
             let _profit_amount = _seedmoney * 10 / 100;
             let profit_amount: felt252 = _profit_amount.into();
             let profit_amount_: u256 = profit_amount.into();
             NGTTokenDispatcher { contract_address: ngttoken_address::read() }.poolMint(caller, profit_amount_);
          }else{
             let after_amount = _seedmoney * 90 / 100;
             let _after_amount: felt252 = after_amount.into();
             let after_amount_: u256 = _after_amount.into();
             NGTTokenDispatcher { contract_address: ngttoken_address::read() }.transfer(caller, after_amount_);
          }
       }
       address_to_seedmoney::write((caller, _index), 0);
       address_to_kinds::write((caller, _index), 0);
       address_to_starttime::write((caller, _index), 0);
    }

    #[view]
    fn get_order_index(_address: ContractAddress) -> u64 {
        address_to_index::read(_address)
    }

    #[view]
    fn get_order_info(_address: ContractAddress) -> Array<OrderInfo>{
       let _index = address_to_index::read(_address);
       if(_index == 0){
          return ArrayTrait::<OrderInfo>::new();
       }
       let mut ordersArray = ArrayTrait::<OrderInfo>::new();
       let mut i: u64 = _index;
       loop {
            if i == 0{
                break();
            }
            let seedmoney = address_to_seedmoney::read((_address, i));
            let kinds = address_to_kinds::read((_address, i));
            let starttime = address_to_starttime::read((_address, i));
            let orders = OrderInfo{ orderindex: i, seedmoney: seedmoney, kinds: kinds, starttime: starttime };
            ordersArray.append(orders);
            i = i-1;
       };
       
       return ordersArray;
    }
}
