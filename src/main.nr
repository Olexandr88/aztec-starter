contract EasyPrivateVoting {
    use dep::aztec::prelude::{AztecAddress, FunctionSelector, PrivateContext, Map, PublicMutable, SharedImmutable};
    #[aztec(storage)]
    struct Storage {
        admin: PublicMutable<AztecAddress>, // admin can end vote
        tally: Map<Field, PublicMutable<Field>>, // we will store candidate as key and number of votes as value
        vote_ended: PublicMutable<bool>, // vote_ended is boolean
        active_at_block: SharedImmutable<u32>, // when people can start voting
    }

    #[aztec(public)]
    #[aztec(initializer)] // annotation to mark function as a constructor
    fn constructor(admin: AztecAddress) {
        storage.admin.write(admin);
        storage.vote_ended.write(false);
        storage.active_at_block.initialize(context.block_number() as u32);
    }

    #[aztec(private)] // annotation to mark function as private and expose private context
    fn cast_vote(candidate: Field) {
        // Below, we make sure to get our nullifier public key at a specific block. By pinning the nullifier public key at a specific block,
        // rotating keys will have no effect on the nullifier being produced, and voting again after will fail because the same nullifier is computed each time the user votes.
        let header_at_active_at_block = context.get_header_at(storage.active_at_block.read_private());
        let msg_sender_npk_m_hash = header_at_active_at_block.get_npk_m_hash(&mut context, context.msg_sender());

        let secret = context.request_nsk_app(msg_sender_npk_m_hash); // get secret key of caller of function
        let nullifier = std::hash::pedersen_hash([context.msg_sender().to_field(), secret]); // derive nullifier from sender and secret
        context.push_nullifier(nullifier);
        EasyPrivateVoting::at(context.this_address()).add_to_tally_public(candidate).enqueue(&mut context);
    }

    #[aztec(public)]
    #[aztec(internal)]
    fn add_to_tally_public(candidate: Field) {
        assert(storage.vote_ended.read() == false, "Vote has ended"); // assert that vote has not ended
        let new_tally = storage.tally.at(candidate).read() + 1;
        storage.tally.at(candidate).write(new_tally);
    }

    #[aztec(public)] 
    fn end_vote() {
        assert(storage.admin.read().eq(context.msg_sender()), "Only admin can end votes"); // assert that caller is admin
        storage.vote_ended.write(true);
    }
    unconstrained fn get_vote(candidate: Field) -> pub Field {
        storage.tally.at(candidate).read()
    }
}
