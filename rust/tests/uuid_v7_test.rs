// input: 
// output: 
// pos: 
use cardmind_rust::utils::uuid_v7::new_uuid_v7;

#[test]
fn it_should_generate_uuid_v7() {
    let value = new_uuid_v7();
    assert_eq!(value.get_version_num(), 7);
}
