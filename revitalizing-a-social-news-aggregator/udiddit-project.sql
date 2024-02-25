--PART I: 
--Investigate the existing schema and write down specific things that could be improved about this schema.
/*
    “bad_posts” does not obey the First Normal Form; upvotes and downvotes contain more than one value.

    There is no foreign key constraint on “post_id” in “bad_comments” (which should reference “id” in “bad_posts”.

    The entity “usernames” should be maintained in a separate table

    The “bad_posts” PK is a SERIAL, whereas the referenced value in “bad_comments” is a BIGINT.

    Votes are of type “text”, which means they cannot be tallied

    Separate tables need to be created for users, comments, posts, topics, and votes, rather than rolling everything up into two tables.
*/

--PART II:
-- Create the DDL for your new schema

--Creation of "Users" table

CREATE TABLE "users" (
    "id" SERIAL,
    "username" VARCHAR(25),
    "last_login" TIMESTAMP,
    CONSTRAINT "users_pk" PRIMARY KEY ("id"),
    CONSTRAINT "unique_username" UNIQUE ("username"),
    CONSTRAINT "non_blank_username" CHECK (LENGTH(TRIM("username"))>0),
    CONSTRAINT "non_null_username" CHECK ("username" IS NOT NULL)
);

CREATE INDEX "last_login" ON "users" ("last_login"); 

--Creation of "Topics" table

CREATE TABLE "topics" (
    "id" SERIAL,
    "name" VARCHAR(30),
    "description" VARCHAR(500),
    "user_id" INTEGER,
    CONSTRAINT "topics_pk" PRIMARY KEY ("id"),
    CONSTRAINT "unique_name" UNIQUE ("name"),
    CONSTRAINT "non_blank_name" CHECK (LENGTH(TRIM("name"))>0),
    CONSTRAINT "non_null_name" CHECK ("name" IS NOT NULL),
    FOREIGN KEY ("user_id") REFERENCES "users" ("id")
);

--Creation of "Posts" table

CREATE TABLE "posts" (
    "id" BIGSERIAL,
    "title" VARCHAR(100),
    "url" VARCHAR(80000),
    "post_body" TEXT,
    "post_time" TIMESTAMP WITH TIME ZONE,
    "topic_id" INTEGER,
    "user_id" INTEGER,
    CONSTRAINT "posts_pk" PRIMARY KEY ("id"),
    CONSTRAINT "non_blank_title" CHECK (LENGTH(TRIM("title"))>0),
    CONSTRAINT "non_null_title" CHECK ("title" IS NOT NULL),
    CONSTRAINT "url_or_body_is_not_null" CHECK 
        (("post_body" IS NOT NULL AND "url" IS NULL) OR 
        ("url" IS NOT NULL AND "post_body" IS NULL)),
    FOREIGN KEY ("topic_id") REFERENCES "topics" ("id") ON DELETE CASCADE,
    CONSTRAINT "non_null_topic_id" CHECK ("topic_id" IS NOT NULL),
    FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE SET NULL
);

CREATE INDEX "url" ON "posts" ("url");

--Creation of "Comments" table

CREATE TABLE "comments" (
    "id" BIGSERIAL,
    "parent_id" BIGINT,
    "comment_body" TEXT,
    "comment_time" TIMESTAMP WITH TIME ZONE,
    "post_id" BIGINT,
    "user_id" INTEGER,
    CONSTRAINT "comments_pk" PRIMARY KEY ("id"),
    CONSTRAINT "non_blank_comment_body" CHECK (LENGTH(TRIM("comment_body"))>0),
    CONSTRAINT "non_null_comment_body" CHECK ("comment_body" IS NOT NULL),
    FOREIGN KEY ("parent_id") REFERENCES "comments" ("id") ON DELETE CASCADE,
    FOREIGN KEY ("post_id") REFERENCES "posts" ("id") ON DELETE CASCADE,
    CONSTRAINT "non_null_post_id" CHECK ("post_id" IS NOT NULL),
    FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE SET NULL
);

CREATE INDEX "parent_id" ON "comments" ("parent_id");

--Creation of "Votes" table

CREATE TABLE "votes" (
    "id" BIGSERIAL,
    "vote" SMALLINT,
    "post_id" BIGINT,
    "user_id" INTEGER,
    CONSTRAINT "votes_pk" PRIMARY KEY ("id"),
    CONSTRAINT "users_cannot_vote_twice" UNIQUE ("post_id","user_id"),
    FOREIGN KEY ("post_id") REFERENCES "posts" ("id") ON DELETE CASCADE,
    CONSTRAINT "non_null_post_id" CHECK ("post_id" IS NOT NULL),
    FOREIGN KEY ("user_id") REFERENCES "users" ("id") ON DELETE SET NULL,
    CONSTRAINT "votes_input_1_or_-1" CHECK (("vote"=1) OR ("vote"=-1))
);

CREATE INDEX "vote" ON "votes" ("vote");

--PART III
-- Migrate the provided data into the new schema

--INSERTING INTO TOPICS

UPDATE "bad_posts" SET "topic" = (
    LEFT("topic",30)
);

INSERT INTO "topics" ("name")
    SELECT DISTINCT "topic"
    FROM "bad_posts";

--Inserting data into "Users" table

INSERT INTO "users" ("username")
    SELECT DISTINCT "username"
    FROM "bad_posts"

    UNION

    SELECT DISTINCT "username"
    FROM "bad_comments"

    UNION

    SELECT DISTINCT REGEXP_SPLIT_TO_TABLE("downvotes", ',') :: VARCHAR(25)
    FROM "bad_posts"

    UNION

    SELECT DISTINCT REGEXP_SPLIT_TO_TABLE("upvotes", ',') :: VARCHAR(25)
    FROM "bad_posts";

--Inserting data into "Posts" table

UPDATE "bad_posts" SET "title" = (
    LEFT("title",100)
);

INSERT INTO "posts" ("title","url","post_body","topic_id","user_id")
    SELECT "bp"."title","bp"."url","bp"."text_content","t"."id","u"."id"
    FROM "bad_posts" bp
    INNER JOIN "topics" t
    ON "t"."name"="bp"."topic"
    INNER JOIN "users" u
    ON "u"."username"="bp"."username";

--Inserting data into "Comments" table

INSERT INTO "comments" ("user_id","post_id","comment_body")
    SELECT "u"."id","p"."id","bc"."text_content"
    FROM "bad_comments" bc
    INNER JOIN "users" u
    ON "u"."username"="bc"."username"
    INNER JOIN "bad_posts" bp
    ON "bp"."id"="bc"."post_id"
    INNER JOIN "posts" p
    ON "p"."title"="bp"."title";

--Inserting data into "Votes" table

ALTER TABLE "votes" ADD COLUMN "username" VARCHAR(25);

INSERT INTO "votes" ("post_id","username")
    SELECT "p"."id", REGEXP_SPLIT_TO_TABLE("downvotes", ',') 
    FROM "bad_posts" bp
    JOIN "posts" p
    ON "p"."title"="bp"."title";

UPDATE "votes" SET "vote" = '-1'
    WHERE "vote" IS NULL;

UPDATE "votes" SET "user_id" = (
    SELECT "users"."id"
    FROM "users"
    WHERE "votes"."username"="users"."username"
);

INSERT INTO "votes" ("post_id","username")
    SELECT "p"."id", REGEXP_SPLIT_TO_TABLE("upvotes", ',') 
    FROM "bad_posts" bp
    JOIN "posts" p
    ON "p"."title"="bp"."title";

UPDATE "votes" SET "vote" = '1'
    WHERE "vote" IS NULL;

UPDATE "votes" SET "user_id" = (
    SELECT "users"."id"
    FROM "users"
    WHERE "votes"."username"="users"."username"
);

ALTER TABLE "votes" DROP COLUMN "username";

--PART IV
--Query the data to answer a series of questions

--List all users who haven’t logged in in the last year

SELECT *
FROM "users"
WHERE "last_login" > (CURRENT_DATE) - interval '1 year'
ORDER BY "last_login";

--List all users who haven’t created any post.

SELECT "u"."username", "u"."id", "p"."user_id"
FROM "users" u
LEFT JOIN "posts" p
ON "u"."id"="p"."user_id"
WHERE "p"."user_id" IS NULL;

--List all topics that don’t have any posts.

SELECT "t"."name", "t"."id", "p"."topic_id"
FROM "topics" t
LEFT JOIN "posts" p
ON "t"."id"="p"."topic_id"
WHERE "p"."topic_id" IS NULL;

--List the latest 20 posts for a given topic.

SELECT "t"."name", "p"."title", "p"."post_time"
FROM "topics" t
INNER JOIN "posts" p
ON "t"."id"="p"."topic_id"
WHERE "t"."id"='1' --random topic chosen
ORDER BY "p"."post_time" DESC
LIMIT 20;

--List the latest 20 posts made by a given user.

SELECT "p"."title", "u"."username", "p"."post_time"
FROM "users" u
INNER JOIN "posts" p
ON "u"."id"="p"."user_id"
WHERE "u"."id"='10951' --random user id chosen
ORDER BY "p"."post_time" DESC
LIMIT 20;

--Find all posts that link to a specific URL, for moderation purposes. 

SELECT *
FROM "posts"
WHERE "url" IS NOT NULL;

--List all the top-level comments (those that don’t have a parent comment) for a given post.

SELECT "p"."title", "c"."comment_body"
FROM "comments" c
INNER JOIN "posts" p
ON "p"."id"="c"."post_id"
WHERE "c"."parent_id" IS NULL and "p"."id"='5'; --random post chosen

--List all the direct children of a parent comment.

SELECT *
FROM "comments"
WHERE "parent_id"=5; --random parent_id chosen

--List the latest 20 comments made by a given user.

SELECT "c"."comment_body"
FROM "comments" c
INNER JOIN "users" u
ON "u"."id"="c"."user_id"
WHERE "u"."id"='1'
ORDER BY "c"."comment_time" DESC
LIMIT 20;

--Compute the score of a post, defined as the difference between the number of upvotes and the number of downvotes

SELECT SUM("vote")
FROM "votes" v
INNER JOIN "posts" p
ON "p"."id"="v"."post_id"
WHERE "p"."id"='1';

--Alternate query where we literally tally the number of upvotes and downvotes

SELECT COUNT(*)
FROM "votes" v
INNER JOIN "posts" p
ON "p"."id"="v"."post_id"
WHERE "vote"='1' AND "p"."id"='1';

SELECT COUNT(*)
FROM "votes" v
INNER JOIN "posts" p
ON "p"."id"="v"."post_id"
WHERE "vote"='-1' AND "p"."id"='1';

CREATE VIEW "votes_up_and_down"
AS
SELECT 
    (SELECT COUNT(*) AS "upvotes_count"
    FROM "votes" v
    INNER JOIN "posts" p
    ON "p"."id"="v"."post_id"
    WHERE "vote"='1' AND "p"."id"='1'),
    COUNT(*) AS "downvotes_count"
FROM "votes" v
INNER JOIN "posts" p
ON "p"."id"="v"."post_id"
WHERE "vote"='-1' AND "p"."id"='1';

SELECT ("upvotes_count"-"downvotes_count") AS "score"
FROM "votes_up_and_down";