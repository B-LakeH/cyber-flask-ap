from app import app, db, User, Post

def view_database():
    """
    Connects to the database and prints the contents of the User and Post tables.
    """
    with app.app_context():
        print("--- Users ---")
        users = User.query.all()
        if not users:
            print("No users found.")
        else:
            for user in users:
                print(f"ID: {user.id}, Email: {user.email}, Password Hash: {user.password}")
        
        print("\n--- Posts ---")
        posts = Post.query.all()
        if not posts:
            print("No posts found.")
        else:
            for post in posts:
                print(f"ID: {post.id}, Content: '{post.content}', Author ID: {post.user_id}")
        print("\n")

if __name__ == '__main__':
    view_database()
