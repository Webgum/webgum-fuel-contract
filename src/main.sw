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
    rating: u64,
    // use IPFS CID here?
    metadata: str[5],
}

storage {
    // buyers: StorageMap<Address, Vec<u64>> = StorageMap {},
    projectListings: StorageVec<Project> = StorageVec {},
    // commissionPercent: u64 = 420,
    // owner: Identity =  Identity::Address(ADDRESS_HERE);
}

abi WebGum {
    #[storage(read, write)]
    fn list_project(price: u64, metadata: str[5]) -> Project;

    // #[storage(read, write)]
    // fn update_project(projectId: u64, price: u64, metadata: str[50]) -> Project;

    // #[storage(read, write)]
    // fn buy_project(projectId: u64);

    // #[storage(read, write)]
    // fn reviewProject(projectId: u64, rating: u64);

    #[storage(read)]
    fn get_project(projectId: u64) -> Project;

    // #[storage(read)]
    // fn hasBoughtProject(projectId: u64, wallet: Address) -> bool;

    // #[storage(read, write)]
    // fn update_owner(identity: Identity);

}

impl WebGum for Contract {
    #[storage(read, write)]
    fn list_project(price: u64, metadata: str[5]) -> Project{
        let index = storage.projectListings.len();
        let sender: Result<Identity, AuthError> = msg_sender();
        let rating: u64 = 0;

        let newProject =  Project {
            projectId: index,
            price: price,
            ownerAddress: sender.unwrap(),
            rating: rating,
            metadata: metadata,
        };

        storage.projectListings.push(newProject);

        return newProject
    }

    // #[storage(read, write)]
    // fn update_project(projectId: u64, price: u64, metadata: str[50]) -> Project{
    //     let project = storage.projectListings.get(projectId).unwrap()
        
    // }

    // #[storage(read, write)]
    // fn buy_project(projectId: u64){
    //     // make payable, require price == payment
        
    //     let sender: Result<Identity, AuthError> = msg_sender();

    //     let project = storage.projectListings.get(projectId).unwrap()

    //     // add to buyer list

    // }

    // #[storage(read, write)]
    // fn reviewProject(projectId: u64, rating: u64){

    // }

    #[storage(read)]
    fn get_project(projectId: u64) -> Project{
        let project = storage.projectListings.get(projectId).unwrap();
        return project
    }

    // #[storage(read)]
    // fn hasBoughtProject(projectId: u64, wallet: Address) -> bool{

    // }

    // #[storage(read, write)]
    //  fn update_owner(identity: Identity) {
    //     storage.owner = Option::Some(identity);
    // }
}
