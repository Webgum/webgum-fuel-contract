contract;

use std::{
    auth::{
        AuthError,
        msg_sender,
    },
    call_frames::msg_asset_id,
    constants::BASE_ASSET_ID,
    context::{
        msg_amount,
        this_balance,
    },
    identity::Identity,
    option::Option,
    storage::StorageMap,
    storage::StorageVec,
    token::transfer,
};

pub struct Project {
    project_id: u64,
    price: u64,
    max_buyers: u64,
    buyer_count: u64,
    owner_address: Identity,
    // encrypted IPFS CID
    metadata: str[59],
}

impl Project {
    fn update_buyer_count(ref mut self) {
        self.buyer_count = self.buyer_count + 1;
    }
}

pub enum InvalidError {
    IncorrectAssetId: (),
    NotEnoughTokens: (),
    CantReview: (),
    InvalidRating: (),
    MaxBuyers: (),
    NotProjectOwner: (),
    OnlyOwner: (),
    OwnerNotInitialized: (),
    OwnerAlreadyInitialized: (),
}

struct Vector {
    inner: [u64; 5],
    current_ix: u64,
}

impl Vector {
    fn new() -> Self {
        Self {
            inner: [0; 5],
            current_ix: 0,
        }
    }

    fn get(ref mut self, ix: u64) -> u64 {
        self.inner[ix]
    }

    fn push(ref mut self, val: u64) {
        // only update if array not full
        match self.current_ix {
            0 => self.inner = [val, 0, 0, 0, 0],
            1 => self.inner = [self.inner[0], val, 0, 0, 0],
            2 => self.inner = [self.inner[0], self.inner[1], val, 0, 0],
            3 => self.inner = [self.inner[0], self.inner[1], self.inner[2], val, 0],
            4 => self.inner = [
                self.inner[0],
                self.inner[1],
                self.inner[2],
                self.inner[3],
                val,
            ],
            _ => revert(5),
        }
        self.current_ix = self.current_ix + 1;
    }
}

storage {
    // ratings: a vector of tuples with the project id, the Identity, and the rating
    ratings: StorageVec<(u64, Identity, u64)> = StorageVec {},
    // ratings_map: map of project id => Vector of rating index locations
    ratings_map: StorageMap<u64, Vector> = StorageMap {},
    // map of buyer Identity => a Vector of project ids they bought
    buyers: StorageMap<Identity, Vector> = StorageMap {},
    creators: StorageMap<Identity, Vector> = StorageMap {},
    // map of project id => Project
    project_listings: StorageMap<u64, Project> = StorageMap {},
    // total # of projects made
    project_count: u64 = 0,
    // owner of the contract
    owner: Option<Identity> = Option::None,
}

abi WebGum {
    // list a new project for sale
    #[storage(read, write)]
    fn list_project(price: u64, max_buyers: u64, metadata: str[59]) -> Project;

    // update an existing project for sale
    #[storage(read, write)]
    fn update_project(project_id: u64, price: u64, max_buyers: u64, metadata: str[59]) -> Project;

    // buy a listed project
    #[storage(read, write)]
    fn buy_project(project_id: u64);

    // review a project you bought with a number 0-5
    #[storage(read, write)]
    fn review_project(project_id: u64, rating: u64) -> u64;

    // get a Project for a given project ID
    #[storage(read)]
    fn get_project(project_id: u64) -> Project;

    // get the total number of projects listed
    #[storage(read)]
    fn get_projects_list_length() -> u64;

    // get the number of projects created by a given Identity
    #[storage(read)]
    fn get_creator_list_length(creator: Identity) -> u64;

    // get the nth Project created by a given Identity
    #[storage(read)]
    fn get_created_project(creator: Identity, index: u64) -> Project;

    // get the nth project ID created by a given Identity
    #[storage(read)]
    fn get_created_project_id(creator: Identity, index: u64) -> u64;

    // get the number of projects bought by a given Identity
    #[storage(read)]
    fn get_buyer_list_length(buyer: Identity) -> u64;

    // get the nth Project bought by a given Identity
    #[storage(read)]
    fn get_bought_project(buyer: Identity, index: u64) -> Project;

    // check if the given Identity has bought the given project_id
    #[storage(read)]
    fn has_bought_project(project_id: u64, wallet: Identity) -> bool;

    // get all of the project IDs created by a given Identity
    #[storage(read)]
    fn get_creator_vector(id: Identity) -> Vector;

    // get all of the project IDs bought by a given Identity
    #[storage(read)]
    fn get_buyer_vector(id: Identity) -> Vector;

    // get the index locations of the reviews for a given project
    #[storage(read)]
    fn get_project_ratings_ix(project_id: u64) -> Vector;

    // get a the Identity of the rater and the project rating (0-5) from a given index
    #[storage(read)]
    fn get_project_rating(index: u64) -> (Identity, u64);

    // a function to set the contract owner
    #[storage(read, write)]
    fn initialize_owner() -> Identity;

    // a function to withdraw contract funds
    #[storage(read)]
    fn withdraw_funds();
}

impl WebGum for Contract {
    #[storage(read, write)]
    fn list_project(price: u64, max_buyers: u64, metadata: str[59]) -> Project {
        let index = storage.project_count;
        let sender: Result<Identity, AuthError> = msg_sender();

        let newProject = Project {
            project_id: index,
            price: price,
            // if unlimited, set to 0
            max_buyers: max_buyers,
            buyer_count: 0,
            owner_address: sender.unwrap(),
            metadata: metadata,
        };

        let mut existing: Vector = storage.creators.get(sender.unwrap());

        // add msg sender to buyer list
        existing.push(index);
        storage.creators.insert(sender.unwrap(), existing);

        storage.project_listings.insert(index, newProject);
        storage.project_count = storage.project_count + 1;

        return newProject
    }
    
    #[storage(read, write)]
    fn update_project(
        project_id: u64,
        price: u64,
        max_buyers: u64,
        metadata: str[59],
    ) -> Project {
        let mut project: Project = storage.project_listings.get(project_id);

        // only allow the owner to update
        let sender: Result<Identity, AuthError> = msg_sender();
        require(sender.unwrap() == project.owner_address, InvalidError::NotProjectOwner);
        if max_buyers > 0 {
            // make sure new max_buyers isn't less than buyer_count
            require(max_buyers > project.buyer_count, InvalidError::MaxBuyers);
        }

        // update project
        project.price = price;
        project.metadata = metadata;
        project.max_buyers = max_buyers;
        storage.project_listings.insert(project_id, project);

        return project;
    }

    #[storage(read, write)]
    fn buy_project(project_id: u64) {
        let asset_id = msg_asset_id();
        let amount = msg_amount();

        let mut project: Project = storage.project_listings.get(project_id);

        if (project.max_buyers > 0) {
            // require buyer_count to be less than the max_buyers limit
            require(project.max_buyers > project.buyer_count, InvalidError::MaxBuyers);
        }

        // add 1 to the buyer count
        project.update_buyer_count();
        // update project_listings
        storage.project_listings.insert(project_id, project);

        // require payment
        require(asset_id == BASE_ASSET_ID, InvalidError::IncorrectAssetId);
        require(amount >= project.price, InvalidError::NotEnoughTokens);

        let sender: Result<Identity, AuthError> = msg_sender();

        let mut existing: Vector = storage.buyers.get(sender.unwrap());

        // add msg sender to buyer list
        existing.push(project_id);
        storage.buyers.insert(sender.unwrap(), existing);

        // only charge commission if price is more than 1_000
        if amount > 1_000 {
            // for every 100 coins, the contract keeps 5
            let commission = amount / 20;
            let new_amount = amount - commission;
            // send the payout minus commission to the seller
            transfer(new_amount, asset_id, project.owner_address);
        } else {
        // send the full payout to the seller
            transfer(amount, asset_id, project.owner_address);
        }
    }

    #[storage(read, write)]
    fn review_project(project_id: u64, rating: u64) -> u64 {
        require(rating < 6, InvalidError::InvalidRating);
        let sender: Result<Identity, AuthError> = msg_sender();
        let mut existing: Vector = storage.buyers.get(sender.unwrap());
        let mut i = 0;
        let mut can_review = false;
        while i < existing.current_ix {
            let project = existing.get(i);
            if project == project_id {
                can_review = true;
            }
            i += 1;
        }

        // require sender has bought the project
        require(can_review, InvalidError::CantReview);

        // add rating to ratings vector
        storage.ratings.push((project_id, sender.unwrap(), rating));

        // add rating index to ratings_map
        let mut existing: Vector = storage.ratings_map.get(project_id);
        let index = storage.ratings.len();
        existing.push(index);
        storage.ratings_map.insert(project_id, existing);
        index
    }

    #[storage(read)]
    fn get_project(project_id: u64) -> Project {
        storage.project_listings.get(project_id)
    }

    #[storage(read)]
    fn get_projects_list_length() -> u64 {
        storage.project_count
    }

    #[storage(read)]
    fn get_creator_list_length(creator: Identity) -> u64 {
        storage.creators.get(creator).current_ix
    }

    #[storage(read)]
    fn get_created_project(creator: Identity, index: u64) -> Project {
        let project_id = storage.creators.get(creator).get(index);
        storage.project_listings.get(project_id)
    }

    #[storage(read)]
    fn get_created_project_id(creator: Identity, index: u64) -> u64 {
        storage.creators.get(creator).get(index)
    }

    #[storage(read)]
    fn get_buyer_list_length(buyer: Identity) -> u64 {
        storage.buyers.get(buyer).current_ix
    }

    #[storage(read)]
    fn get_bought_project(buyer: Identity, index: u64) -> Project {
        let project_id = storage.buyers.get(buyer).get(index);
        storage.project_listings.get(project_id)
    }

    #[storage(read)]
    fn has_bought_project(project_id: u64, wallet: Identity) -> bool {
        let mut existing: Vector = storage.buyers.get(wallet);

        let mut i = 0;
        while i < existing.current_ix {
            let project = existing.get(i);
            if project == project_id {
                return true;
            }
            i += 1;
        }

        return false;
    }

    #[storage(read)]
    fn get_creator_vector(id: Identity) -> Vector {
        storage.creators.get(id)
    }

    #[storage(read)]
    fn get_buyer_vector(id: Identity) -> Vector {
        storage.buyers.get(id)
    }

    #[storage(read)]
    fn get_project_ratings_ix(project_id: u64) -> Vector {
        storage.ratings_map.get(project_id)
    }

    #[storage(read)]
    fn get_project_rating(index: u64) -> (Identity, u64) {
        let rating_result = storage.ratings.get(index);
        let rating_tuple = match rating_result {
            Option::Some(rating_result) => rating_result,
            Option::None => revert(50),
        };
        (rating_tuple.1, rating_tuple.2)
    }

    #[storage(read, write)]
    fn initialize_owner() -> Identity {
        let owner = storage.owner;
    // make sure the owner has NOT already been initialized
        require(owner.is_none(), InvalidError::OwnerAlreadyInitialized);
    // get the identity of the sender
        let sender: Result<Identity, AuthError> = msg_sender(); 
    // set the owner to the sender's identity
        storage.owner = Option::Some(sender.unwrap());
    // return the owner
        sender.unwrap()
    }

    #[storage(read)]
    fn withdraw_funds() {
        let owner = storage.owner;
        // make sure the owner has been initialized
        require(owner.is_some(), InvalidError::OwnerNotInitialized);
        let sender: Result<Identity, AuthError> = msg_sender(); 
        // require the sender to be the owner
        require(sender.unwrap() == owner.unwrap(), InvalidError::OnlyOwner);

        // get the current balance of this contract for the base asset
        let amount = this_balance(BASE_ASSET_ID);

        // require the contract balance to be more than 0
        require(amount > 0, InvalidError::NotEnoughTokens);
        // send the amount to the owner
        transfer(amount, BASE_ASSET_ID, owner.unwrap());
    }
}
