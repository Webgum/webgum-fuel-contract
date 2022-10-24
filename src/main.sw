contract;

use std::storage::StorageVec;
use std::storage::StorageMap;
use std::identity::Identity;
use std::option::Option;
use std::chain::auth::{AuthError, msg_sender};

pub struct Project {
    projectId: u64,
    price: u64,
    ownerAddress: Identity,
    // use IPFS CID here?
    metadata: str[5],
}

storage {
    // map of project ids to a vector of ratings
    // ratings: StorageMap<u64, Vec<u64>> = StorageMap {},
    buyers: StorageMap<Identity, Vec<u64>> = StorageMap {},
    projectListings: StorageVec<Project> = StorageVec {},
    // commissionPercent: u64 = 420,
    // owner: Identity =  Identity::Address(ADDRESS_HERE);
}

abi WebGum {
    #[storage(read, write)]
    fn list_project(price: u64, metadata: str[5]) -> Project;

    // #[storage(read, write)]
    // fn update_project(projectId: u64, price: u64, metadata: str[50]) -> Project;

    #[storage(read, write)]
    fn buy_project(projectId: u64) -> Identity;

    // #[storage(read, write)]
    // fn reviewProject(projectId: u64, rating: u64);

    #[storage(read)]
    fn get_project(projectId: u64) -> Project;

    #[storage(read)]
    fn has_bought_project(projectId: u64, wallet: Identity) -> bool;

    // #[storage(read, write)]
    // fn update_owner(identity: Identity);

}

impl WebGum for Contract {
    #[storage(read, write)]
    fn list_project(price: u64, metadata: str[5]) -> Project{
        let index = storage.projectListings.len();
        let sender: Result<Identity, AuthError> = msg_sender();

        let newProject =  Project {
            projectId: index,
            price: price,
            ownerAddress: sender.unwrap(),
            metadata: metadata,
        };

        storage.projectListings.push(newProject);

        return newProject
    }

    // #[storage(read, write)]
    // fn update_project(projectId: u64, price: u64, metadata: str[50]) -> Project{
    //     let project = storage.projectListings.get(projectId).unwrap()
        
    // }

    #[storage(read, write)]
    fn buy_project(projectId: u64) -> Identity{
        // make payable, require price == payment
        
        let sender: Result<Identity, AuthError> = msg_sender();

        let mut existing: Vec<u64> = storage.buyers.get(sender.unwrap());

        // add msg sender to buyer list
        if existing.len() < 1 {
            let mut buyerList = ~Vec::new();
            buyerList.push(projectId);
            storage.buyers.insert(sender.unwrap(), buyerList);
        } else {
            existing.push(projectId);
            storage.buyers.insert(sender.unwrap(), existing);
        }

        return sender.unwrap();

    }

    // #[storage(read, write)]
    // fn reviewProject(projectId: u64, rating: u64){

    // }

    #[storage(read)]
    fn get_project(projectId: u64) -> Project{
        let project = storage.projectListings.get(projectId).unwrap();
        return project
    }

    #[storage(read)]
    fn has_bought_project(projectId: u64, wallet: Identity) -> bool{
         let sender: Result<Identity, AuthError> = msg_sender();

        let existing: Vec<u64> = storage.buyers.get(sender.unwrap());

    let mut i = 0;
    let mut hasBought = false;
    while i < existing.len() {
        let project = existing.get(i).unwrap();
        if project == projectId {
            hasBought = true;
        }
        i += 1;
    }

    return hasBought;

}

    // #[storage(read, write)]
    //  fn update_owner(identity: Identity) {
    //     storage.owner = Option::Some(identity);
    // }
}
