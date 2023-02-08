#[cfg(test)]
mod policy_tests {
    use super::super::*;

    // struct TestContext {
    //     empty_user: User,
    // }

    // impl PolicyStore for TestContext {
    //     fn list_users(&self) -> Result<Vec<User>, ()> {
    //         todo!()
    //     }
    //     fn create_user(&self, user: &User) -> Result<(), ()> {
    //         todo!()
    //     }
    //     fn update_user(&self, user: &User) -> Result<(), ()> {
    //         todo!()
    //     }
    //     fn set_user_password(&self, login_name: &str, password: Option<&str>) -> Result<(), ()> {
    //         todo!()
    //     }
    //     fn authenticate_user(&self, login_name: &str, password: &str) -> Result<User, ()> {
    //         todo!()
    //     }
    //     fn user_named(&self, name: &str) -> Result<User, ()> {
    //         todo!()
    //     }
    //     fn list_groups(&self) -> Result<Vec<Group>, ()> {
    //         todo!()
    //     }
    //     fn group_named(&self, name: &str) -> Option<Group> {
    //         todo!()
    //     }
    // }

    // fn setup() -> TestContext {
    //     TestContext {
    //         empty_user: User {
    //             login_name: String::from("username"),
    //             full_name: None,
    //             groups: Vec::new(),
    //             policy_statements: Vec::new(),
    //         },
    //     }
    // }

    // #[test]
    // fn test_user_may_perform_empty_denies() {
    //     let ctx = setup();
    //     assert_eq!(
    //         false,
    //         ctx.empty_user
    //             .may_perform(Box::new(ctx), "some:action", "some:resource")
    //     );
    // }
}
