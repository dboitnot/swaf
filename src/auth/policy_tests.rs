#[cfg(test)]
mod policy_tests {
    use super::super::*;

    struct TestContext {
        empty_user: User,
    }

    impl PolicyStore for TestContext {
        fn group_named(&self, name: &str) -> Option<&Group> {
            match name {
                _ => None,
            }
        }
    }

    fn setup() -> TestContext {
        TestContext {
            empty_user: User {
                login_name: String::from("username"),
                full_name: None,
                groups: Vec::new(),
                policy_statements: Vec::new(),
            },
        }
    }

    #[test]
    fn test_user_may_perform_empty_denies() {
        let ctx = setup();
        assert_eq!(
            false,
            ctx.empty_user
                .may_perform(&ctx, "some:action", "some:resource")
        );
    }
}
