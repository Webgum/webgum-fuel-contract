use fuels::{prelude::*, tx::ContractId};

// Load abi from json
abigen!(MyContract, "out/debug/webgum-contract-abi.json");

async fn get_contract_instance() -> (MyContract, ContractId) {
    // Launch a local network and deploy the contract
    let mut wallets = launch_custom_provider_and_get_wallets(
        WalletsConfig::new(
            Some(1),             /* Single wallet */
            Some(1),             /* Single coin (UTXO) */
            Some(1_000_000_000), /* Amount per coin */
        ),
        None,
    )
    .await;
    let wallet = wallets.pop().unwrap();

    let id = Contract::deploy(
        "./out/debug/webgum-contract.bin",
        &wallet,
        TxParameters::default(),
        StorageConfiguration::with_storage_path(Some(
            "./out/debug/webgum-contract-storage_slots.json".to_string(),
        )),
    )
    .await
    .unwrap();

    let instance = MyContractBuilder::new(id.to_string(), wallet).build();

    (instance, id.into())
}

#[tokio::test]
async fn can_get_contract_id() {
    let (instance, _id) = get_contract_instance().await;

    // Now you have an instance of your contract you can use to test each function

    let metadata: fuels::core::types::SizedAsciiString<5> = "abcde".try_into().expect("Should have succeeded");
    let price: u64 = 1;
    
    let result1 = instance.list_project(price, metadata).call().await.unwrap();
    let result2 = instance.get_project(0).call().await.unwrap();
    assert!(result1.value == result2.value);

    // buy project
    // TO DO: send project price

    // let wallet_address = instance.buy_project(0).call().await.unwrap();
    // let has_project = instance.has_bought_project(0, wallet_address.value).call().await.unwrap();
    // assert!(has_project.value == true);
    
}
