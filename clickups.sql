CREATE TABLE IF NOT EXISTS "User"
(
    username character varying(50)  NOT NULL PRIMARY KEY,
    password character varying(50)  NOT NULL,
    email    character varying(254) NOT NULL
);

INSERT INTO "User" (username, password, email)
VALUES ('ELITE', '1234', 'Elite@Elimail.info')
     , ('Qre', '4321', 'Qre@Qre.com')
     , ('Mmd', '7159', 'Mmm@Qre.com');


CREATE TABLE IF NOT EXISTS "Team"
(
    team_id serial                NOT NULL PRIMARY KEY,
    name    character varying(50) NOT NULL
);

INSERT INTO "Team" (name)
VALUES ('The first team built to test')
     , ('The second team built to test');


CREATE TABLE IF NOT EXISTS "Membership"
(
    team_id   serial                NOT NULL,
    username  character varying(50) NOT NULL,
    role      character varying(50) NOT NULL,
    joined_at timestamp with time zone DEFAULT now() CHECK ( joined_at <= now() ),

    PRIMARY KEY (team_id, username),

    FOREIGN KEY (team_id)
        REFERENCES "Team" (team_id) ON DELETE CASCADE ON UPDATE CASCADE,

    FOREIGN KEY (username)
        REFERENCES "User" (username) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "Membership_team_id" ON "Membership" USING btree (team_id);

CREATE INDEX "Membership_user_id" ON "Membership" USING btree (username);

ALTER TABLE "Membership"
    ADD CONSTRAINT roles_options CHECK ( role in ('owner', 'member') );

INSERT INTO "Membership" (team_id, username, role)
VALUES (1, 'Qre', 'owner'),
       (1, 'Mmd', 'member');


CREATE TABLE IF NOT EXISTS "Collection"
(
    collection_id uuid                  NOT NULL PRIMARY KEY,
    type          character varying(50) NOT NULL
);

CREATE INDEX "Collection_collection_id" ON "Collection" USING btree (collection_id);

ALTER TABLE "Collection"
    ADD CONSTRAINT collection_type CHECK ( type in ('Workspace', 'Space', 'List') );

CREATE OR REPLACE FUNCTION CD_Collection_insert()
    RETURNS TRIGGER AS
$$
BEGIN
    IF NOT exists(
            SELECT * FROM "Collection" O WHERE O.collection_id = new.collection_ptr_id) THEN

        INSERT INTO "Collection" VALUES (new.collection_ptr_id, TG_ARGV[0]);

    ELSIF exists(SELECT *
                 FROM "Collection" O
                 WHERE O.collection_id = new.collection_ptr_id
                    OR O.type != TG_ARGV[0]) THEN

        RAISE EXCEPTION '% collection record not found.', TG_ARGV[0] USING HINT = 'U must create collection record first!';

    END IF;
    RETURN new;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Update_Collection()
    RETURNS TRIGGER AS
$$
BEGIN
    UPDATE "Collection" SET collection_id = new.collection_ptr_id WHERE collection_id = old.collection_ptr_id;
    RETURN new;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Delete_Collection()
    RETURNS TRIGGER AS
$$
BEGIN
    DELETE FROM "Collection" WHERE collection_id = new.collection_ptr_id;
    RETURN old;
END
$$ LANGUAGE plpgsql;


CREATE TABLE IF NOT EXISTS "Workspace"
(
    collection_ptr_id uuid                  NOT NULL PRIMARY KEY,
    name              character varying(50) NOT NULL,

    FOREIGN KEY (collection_ptr_id)
        REFERENCES "Collection" (collection_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "Workspace_collection_ptr_id" ON "Workspace" USING btree (collection_ptr_id);

CREATE TRIGGER Insert_workspace
    BEFORE INSERT
    ON "Workspace"
    FOR EACH ROW
EXECUTE PROCEDURE CD_Collection_insert('Workspace');

CREATE TRIGGER Update_workspace
    BEFORE UPDATE
    ON "Workspace"
    FOR EACH ROW
    WHEN ( old.collection_ptr_id != new.collection_ptr_id )
execute procedure Update_Collection();

CREATE TRIGGER delete_workspace
    AFTER DELETE
    ON "Workspace"
    FOR EACH ROW
execute procedure Delete_Collection();

INSERT INTO "Workspace" (collection_ptr_id, name)
VALUES ('205e74d57e5645d2ae5dd87736b48eb2', 'First Workspace')
     , ('bee1e7ff0eb54d67950a188f1c3cd185', 'Second Workspace');


CREATE TABLE IF NOT EXISTS "Space"
(
    collection_ptr_id uuid                  NOT NULL PRIMARY KEY,
    workspace_id      uuid                  NOT NULL,
    name              character varying(50) NOT NULL,

    FOREIGN KEY (collection_ptr_id)
        REFERENCES "Collection" (collection_id) ON DELETE CASCADE ON UPDATE CASCADE,

    FOREIGN KEY (workspace_id)
        REFERENCES "Workspace" (collection_ptr_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "Space_workspace_id" ON "Space" USING btree (workspace_id);

CREATE INDEX "Space_collection_ptr_id" ON "Space" USING btree (collection_ptr_id);

CREATE TRIGGER Insert_space
    BEFORE INSERT
    ON "Space"
    FOR EACH ROW
EXECUTE PROCEDURE CD_Collection_insert('Space');

CREATE TRIGGER Update_space
    BEFORE UPDATE
    ON "Space"
    FOR EACH ROW
    WHEN ( old.collection_ptr_id != new.collection_ptr_id )
execute procedure Update_Collection();

CREATE TRIGGER delete_space
    AFTER DELETE
    ON "Space"
    FOR EACH ROW
execute procedure Delete_Collection();

INSERT INTO "Space" (collection_ptr_id, workspace_id, name)
VALUES ('847c1f8a5879438baea8b28a3f9fe8ef', '205e74d57e5645d2ae5dd87736b48eb2', 'First Space')
     , ('527987b41d2c4e9d935fda41e2400ee3', 'bee1e7ff0eb54d67950a188f1c3cd185', 'Second Space');


CREATE TABLE IF NOT EXISTS "List"
(
    collection_ptr_id uuid                  NOT NULL PRIMARY KEY,
    space_id          uuid                  NOT NULL,
    name              character varying(50) NOT NULL,

    FOREIGN KEY (collection_ptr_id)
        REFERENCES "Collection" (collection_id) ON DELETE CASCADE ON UPDATE CASCADE,

    FOREIGN KEY (space_id)
        REFERENCES "Space" (collection_ptr_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "List_space_id" ON "List" USING btree (space_id);

CREATE INDEX "List_collection_ptr_id" ON "List" USING btree (collection_ptr_id);

CREATE TRIGGER Insert_list
    BEFORE INSERT
    ON "List"
    FOR EACH ROW
EXECUTE PROCEDURE CD_Collection_insert('List');

CREATE TRIGGER Update_list
    BEFORE UPDATE
    ON "List"
    FOR EACH ROW
    WHEN ( old.collection_ptr_id != new.collection_ptr_id )
execute procedure Update_Collection();

CREATE TRIGGER delete_list
    AFTER DELETE
    ON "List"
    FOR EACH ROW
execute procedure Delete_Collection();

INSERT INTO "List" (collection_ptr_id, space_id, name)
VALUES ('7ea3cf45f75d49fea81cb951a3e1db95', '847c1f8a5879438baea8b28a3f9fe8ef', 'First List')
     , ('2742d3b57d394fbc9cd7c6cddf493522', '527987b41d2c4e9d935fda41e2400ee3', 'Second List');


CREATE TABLE IF NOT EXISTS "UserCollections"
(
    collection_id uuid                  NOT NULL,
    username      character varying(50) NOT NULL,
    role          character varying(50) NOT NULL,

    PRIMARY KEY (collection_id, username),

    FOREIGN KEY (collection_id)
        REFERENCES "Collection" (collection_id) ON DELETE CASCADE ON UPDATE CASCADE,

    FOREIGN KEY (username)
        REFERENCES "User" (username) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "UserCollections_collection_id" ON "UserCollections" USING btree (collection_id);

CREATE INDEX "UserCollections_username" ON "UserCollections" USING btree (username);

ALTER TABLE "UserCollections"
    ADD CONSTRAINT uc_roles CHECK ( role in ('owner', 'editor', 'visitor') );

INSERT INTO "UserCollections" (collection_id, username, role)
VALUES ('205e74d57e5645d2ae5dd87736b48eb2', 'Qre', 'owner')
     , ('bee1e7ff0eb54d67950a188f1c3cd185', 'Qre', 'owner');


CREATE TABLE IF NOT EXISTS "TeamCollections"
(
    collection_id uuid                  NOT NULL,
    team_id       serial                NOT NULL,
    role          character varying(50) NOT NULL,

    PRIMARY KEY (collection_id, team_id),

    FOREIGN KEY (collection_id)
        REFERENCES "Collection" (collection_id) ON DELETE CASCADE ON UPDATE CASCADE,

    FOREIGN KEY (team_id)
        REFERENCES "Team" (team_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "TeamCollections_collection_id" ON "TeamCollections" USING btree (collection_id);

CREATE INDEX "TeamCollections_username" ON "TeamCollections" USING btree (team_id);

ALTER TABLE "TeamCollections"
    ADD CONSTRAINT tc_roles CHECK ( role in ('editor', 'visitor') );

INSERT INTO "TeamCollections" (collection_id, team_id, role)
VALUES ('205e74d57e5645d2ae5dd87736b48eb2', 1, 'editor');


CREATE TABLE IF NOT EXISTS "Objective"
(
    objective_id uuid                  NOT NULL PRIMARY KEY,
    type         character varying(50) NOT NULL
);

CREATE INDEX "Objective_objective_id" ON "Objective" USING btree (objective_id);

ALTER TABLE "Objective"
    ADD CONSTRAINT objective_types CHECK ( type in ('Goal', 'Task') );

CREATE OR REPLACE FUNCTION CD_Objective_insert()
    RETURNS TRIGGER AS
$$
BEGIN
    IF NOT exists(
            SELECT * FROM "Objective" O WHERE O.objective_id = new.objective_ptr_id) THEN

        INSERT INTO "Objective" VALUES (new.objective_ptr_id, TG_ARGV[0]);

    ELSIF exists(SELECT *
                 FROM "Objective" O
                 WHERE O.objective_id = new.objective_ptr_id
                    OR O.type != TG_ARGV[0]) THEN

        RAISE EXCEPTION '% objective record not found.', TG_ARGV[0] USING HINT = 'U must create objective record first!';

    END IF;
    RETURN new;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Update_Objective()
    RETURNS TRIGGER AS
$$
BEGIN
    UPDATE "Objective" SET objective_id = new.objective_ptr_id WHERE objective_id = old.objective_ptr_id;
    RETURN new;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Delete_Objective()
    RETURNS TRIGGER AS
$$
BEGIN
    DELETE FROM "Objective" WHERE objective_id = new.objective_ptr_id;
    RETURN old;
END
$$ LANGUAGE plpgsql;


CREATE TABLE IF NOT EXISTS "Task"
(
    objective_ptr_id uuid                   NOT NULL PRIMARY KEY,
    name             character varying(100) NOT NULL,
    priority         integer                  DEFAULT 1,
    statement        boolean                  DEFAULT FALSE,
    description      character varying(500),
    start_time       timestamp with time zone DEFAULT now(),
    end_time         timestamp with time zone,
    list_id          uuid                   NOT NULL,

    FOREIGN KEY (list_id)
        REFERENCES "List" (collection_ptr_id) ON DELETE CASCADE ON UPDATE CASCADE,

    FOREIGN KEY (objective_ptr_id)
        REFERENCES "Objective" (objective_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "Task_list_id" ON "Task" USING btree (list_id);

CREATE INDEX "Task_objective_ptr_id" ON "Task" USING btree (objective_ptr_id);

CREATE TRIGGER Insert_task
    BEFORE INSERT
    ON "Task"
    FOR EACH ROW
EXECUTE PROCEDURE CD_Objective_insert('Task');

CREATE TRIGGER Update_task
    BEFORE UPDATE
    ON "Task"
    FOR EACH ROW
    WHEN ( old.objective_ptr_id != new.objective_ptr_id )
execute procedure Update_Objective();

CREATE TRIGGER delete_task
    AFTER DELETE
    ON "Task"
    FOR EACH ROW
execute procedure Delete_Objective();

INSERT INTO "Task" (objective_ptr_id, name, description, list_id, start_time, end_time)
VALUES ('e789112ce7df4d888897cfcd551ecc1e', 'First Task', 'Description', '7ea3cf45f75d49fea81cb951a3e1db95', now(),
        now() + interval '1 month')
     , ('764ac120eaa746ba834f0a0b14f881a8', 'Secnd Task', 'Description', '7ea3cf45f75d49fea81cb951a3e1db95', now(),
        now() + interval '1 week');

INSERT INTO "Task" (objective_ptr_id, name, description, list_id, statement)
VALUES ('6880765dd09d4cf6b2cb79a7b5acc1ad', 'Third Task', 'Description', '7ea3cf45f75d49fea81cb951a3e1db95', False)
     , ('0d5efccbd8d64ae6b940004dd59d3961', 'Forth Task', 'Description', '7ea3cf45f75d49fea81cb951a3e1db95', True);


CREATE TABLE IF NOT EXISTS "Task_sub_tasks"
(
    from_task uuid NOT NULL,
    to_task   uuid NOT NULL,

    PRIMARY KEY (from_task, to_task),

    FOREIGN KEY (from_task)
        REFERENCES "Task" (objective_ptr_id) ON DELETE CASCADE ON UPDATE CASCADE,

    FOREIGN KEY (to_task)
        REFERENCES "Task" (objective_ptr_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "Task_sub_tasks_from" ON "Task_sub_tasks" USING btree (from_task);

CREATE INDEX "Task_sub_tasks_to" ON "Task_sub_tasks" USING btree (to_task);

INSERT INTO "Task_sub_tasks" (from_task, to_task)
VALUES ('764ac120eaa746ba834f0a0b14f881a8', '0d5efccbd8d64ae6b940004dd59d3961'),
       ('764ac120eaa746ba834f0a0b14f881a8', '6880765dd09d4cf6b2cb79a7b5acc1ad');


CREATE TABLE IF NOT EXISTS "Statement"
(
    statement_id uuid NOT NULL PRIMARY KEY,
    done         boolean               DEFAULT False,
    type         character varying(50) DEFAULT 'Boolean'
);

ALTER TABLE "Statement"
    ADD CONSTRAINT statement_type CHECK ( type in ('Range', 'Currency', 'Boolean') );

CREATE OR REPLACE FUNCTION CD_Statement_insert()
    RETURNS TRIGGER AS
$$
BEGIN
    IF NOT exists(
            SELECT * FROM "Statement" O WHERE O.statement_id = new.statement_ptr_id) THEN

        INSERT INTO "Statement" (statement_id, type) VALUES (new.statement_ptr_id, TG_ARGV[0]);

    ELSIF exists(SELECT *
                 FROM "Statement" O
                 WHERE O.statement_id = new.statement_ptr_id
                    OR O.type != TG_ARGV[0]) THEN

        RAISE EXCEPTION '% statement record not found.', TG_ARGV[0] USING HINT = 'U must create statement record first!';

    END IF;
    RETURN new;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Update_Statement()
    RETURNS TRIGGER AS
$$
BEGIN
    UPDATE "Statement" SET statement_id = new.statement_ptr_id WHERE statement_id = old.statement_ptr_id;
    RETURN new;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Delete_Statement()
    RETURNS TRIGGER AS
$$
BEGIN
    DELETE FROM "Statement" WHERE statement_id = new.statement_ptr_id;
    RETURN old;
END
$$ LANGUAGE plpgsql;

INSERT INTO "Statement" (statement_id)
VALUES ('0fddeb4d888c4b558840024af5423f4f');


CREATE TABLE IF NOT EXISTS "Range"
(
    statement_ptr_id uuid    NOT NULL PRIMARY KEY,
    start            integer NOT NULL,
    "end"            integer NOT NULL,
    "now"            integer NOT NULL,

    CHECK ( start <= "now" AND "now" <= "end" ),

    FOREIGN KEY (statement_ptr_id)
        REFERENCES "Statement" (statement_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TRIGGER Insert_range
    BEFORE INSERT
    ON "Range"
    FOR EACH ROW
EXECUTE PROCEDURE CD_Statement_insert('Range');

CREATE TRIGGER Update_range
    BEFORE UPDATE
    ON "Range"
    FOR EACH ROW
    WHEN ( old.statement_ptr_id != new.statement_ptr_id )
execute procedure Update_Statement();

CREATE TRIGGER delete_range
    AFTER DELETE
    ON "Range"
    FOR EACH ROW
execute procedure Delete_Statement();

INSERT INTO "Range" (statement_ptr_id, start, "end", "now")
VALUES ('aacff363fb3c4b0ab65094b5ad017fcc', 0, 10, 5);


CREATE TABLE IF NOT EXISTS "Currency"
(
    statement_ptr_id uuid          NOT NULL PRIMARY KEY,
    start            numeric(6, 2) NOT NULL,
    "end"            numeric(6, 2) NOT NULL,
    "now"            numeric(6, 2) NOT NULL,

    CHECK ( start <= "now" AND "now" <= "end" ),

    FOREIGN KEY (statement_ptr_id)
        REFERENCES "Statement" (statement_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TRIGGER Insert_currency
    BEFORE INSERT
    ON "Currency"
    FOR EACH ROW
EXECUTE PROCEDURE CD_Statement_insert('Currency');

CREATE TRIGGER Update_currency
    BEFORE UPDATE
    ON "Currency"
    FOR EACH ROW
    WHEN ( old.statement_ptr_id != new.statement_ptr_id )
execute procedure Update_Statement();

CREATE TRIGGER delete_currency
    AFTER DELETE
    ON "Currency"
    FOR EACH ROW
execute procedure Delete_Statement();

INSERT INTO "Currency" (statement_ptr_id, start, "end", "now")
VALUES ('f31b8679110a426b97eb84d9ae9c187b', 0.00, 100.00, 55.55);


CREATE TABLE IF NOT EXISTS "Goal"
(
    objective_ptr_id uuid                   NOT NULL PRIMARY KEY,
    motivations      text                   NOT NULL,
    name             character varying(100) NOT NULL,
    description      character varying(500),
    statement_id     uuid                   NOT NULL,

    FOREIGN KEY (objective_ptr_id)
        REFERENCES "Objective" (objective_id) ON DELETE CASCADE ON UPDATE CASCADE,

    FOREIGN KEY (statement_id)
        REFERENCES "Statement" (statement_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "Goal_objective_ptr_id" ON "Goal" USING btree (objective_ptr_id);

CREATE INDEX "Goal_statement_id" ON "Goal" USING btree (statement_id);

CREATE TRIGGER Insert_goal
    BEFORE INSERT
    ON "Goal"
    FOR EACH ROW
EXECUTE PROCEDURE CD_Objective_insert('Goal');

CREATE TRIGGER Update_goal
    BEFORE UPDATE
    ON "Goal"
    FOR EACH ROW
    WHEN ( old.objective_ptr_id != new.objective_ptr_id )
execute procedure Update_Objective();

CREATE TRIGGER delete_goal
    AFTER DELETE
    ON "Goal"
    FOR EACH ROW
execute procedure Delete_Objective();

INSERT INTO "Goal" (objective_ptr_id, motivations, name, description, statement_id)
VALUES ('8743486f8def4d50a7b9288c32575c72', 'You can.', '#_#', 'description', 'f31b8679110a426b97eb84d9ae9c187b')
     , ('f991a0a3b83247159405308f517374a2', 'You can.', '#_#', 'description', 'aacff363fb3c4b0ab65094b5ad017fcc');


CREATE TABLE IF NOT EXISTS "View"
(
    view_id uuid                  NOT NULL PRIMARY KEY,
    type    character varying(50) NOT NULL
);

CREATE INDEX "View_name" ON "View" USING btree (view_id);

ALTER TABLE "View"
    ADD CONSTRAINT view_type CHECK ( type in ('Calendar', 'Gratt', 'Board') );

CREATE OR REPLACE FUNCTION CD_View_insert()
    RETURNS TRIGGER AS
$$
BEGIN
    IF NOT exists(
            SELECT * FROM "View" O WHERE O.view_id = new.view_ptr_id) THEN

        INSERT INTO "View" (view_id, type) VALUES (new.view_ptr_id, TG_ARGV[0]);

    ELSIF exists(SELECT *
                 FROM "View" O
                 WHERE O.view_id = new.view_ptr_id
                    OR O.type != TG_ARGV[0]) THEN

        RAISE EXCEPTION '% view record not found.', TG_ARGV[0] USING HINT = 'U must create view record first!';

    END IF;
    RETURN new;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Update_View()
    RETURNS TRIGGER AS
$$
BEGIN
    UPDATE "View" SET view_id = new.view_ptr_id WHERE view_id = old.view_ptr_id;
    RETURN new;
END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION Delete_View()
    RETURNS TRIGGER AS
$$
BEGIN
    DELETE FROM "View" WHERE view_id = new.view_ptr_id;
    RETURN old;
END
$$ LANGUAGE plpgsql;

CREATE TABLE IF NOT EXISTS "Gratt"
(
    view_ptr_id uuid                     NOT NULL PRIMARY KEY,
    start       timestamp with time zone NOT NULL,
    "end"       timestamp with time zone NOT NULL,

    FOREIGN KEY (view_ptr_id)
        REFERENCES "View" (view_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "Gratt_view_ptr_id" ON "Gratt" USING btree (view_ptr_id);

CREATE TRIGGER Insert_gratt
    BEFORE INSERT
    ON "Gratt"
    FOR EACH ROW
EXECUTE PROCEDURE CD_View_insert('Gratt');

CREATE TRIGGER Update_gratt
    BEFORE UPDATE
    ON "Gratt"
    FOR EACH ROW
    WHEN ( old.view_ptr_id != new.view_ptr_id )
execute procedure Update_View();

CREATE TRIGGER delete_gratt
    AFTER DELETE
    ON "Gratt"
    FOR EACH ROW
execute procedure Delete_View();

INSERT INTO "Gratt" (view_ptr_id, start, "end")
VALUES ('be7fa014feab40be9d2834ccd709b6c2', now() - interval '1 day', now() + interval '1 day');


CREATE TABLE IF NOT EXISTS "Calendar"
(
    view_ptr_id uuid                     NOT NULL PRIMARY KEY,
    start       timestamp with time zone NOT NULL,
    "end"       timestamp with time zone NOT NULL,

    CHECK ( start < "end" ),

    FOREIGN KEY (view_ptr_id)
        REFERENCES "View" (view_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "Calendar_view_ptr_id" ON "Calendar" USING btree (view_ptr_id);

CREATE TRIGGER Insert_calendar
    BEFORE INSERT
    ON "Calendar"
    FOR EACH ROW
EXECUTE PROCEDURE CD_View_insert('Calendar');

CREATE TRIGGER Update_calendar
    BEFORE UPDATE
    ON "Calendar"
    FOR EACH ROW
    WHEN ( old.view_ptr_id != new.view_ptr_id )
execute procedure Update_View();

CREATE TRIGGER delete_calendar
    AFTER DELETE
    ON "Calendar"
    FOR EACH ROW
execute procedure Delete_View();

INSERT INTO "Calendar" (view_ptr_id, start, "end")
VALUES ('68f245936b794286835293af6b863deb', now() - interval '1 day', now() + interval '1 day');


CREATE TABLE IF NOT EXISTS "Board"
(
    view_ptr_id     uuid     NOT NULL PRIMARY KEY,
    show_progress   boolean DEFAULT False,
    show_estimation boolean DEFAULT False,
    timeunit        interval NOT NULL,

    FOREIGN KEY (view_ptr_id)
        REFERENCES "View" (view_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "Board_view_ptr_id" ON "Board" USING btree (view_ptr_id);

CREATE TRIGGER Insert_board
    BEFORE INSERT
    ON "Board"
    FOR EACH ROW
EXECUTE PROCEDURE CD_View_insert('Board');

CREATE TRIGGER Update_board
    BEFORE UPDATE
    ON "Board"
    FOR EACH ROW
    WHEN ( old.view_ptr_id != new.view_ptr_id )
execute procedure Update_View();

CREATE TRIGGER delete_board
    AFTER DELETE
    ON "Board"
    FOR EACH ROW
execute procedure Delete_View();

INSERT INTO "Board" (view_ptr_id, show_progress, show_estimation, timeunit)
VALUES ('0a2b414cf6354e1f9bc0f2d53b2726ac', TRUE, TRUE, interval '1 day');


CREATE TABLE IF NOT EXISTS "CollectionView"
(
    collection_id uuid NOT NULL,
    view_id       uuid NOT NULL,

    PRIMARY KEY (collection_id, view_id),

    FOREIGN KEY (collection_id)
        REFERENCES "Collection" (collection_id) ON DELETE CASCADE ON UPDATE CASCADE,

    FOREIGN KEY (view_id)
        REFERENCES "View" (view_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "CollectionView_collection_id" ON "CollectionView" USING btree (collection_id);

CREATE INDEX "CollectionView_view_id" ON "CollectionView" USING btree (view_id);

INSERT INTO "CollectionView" (collection_id, view_id)
VALUES ('7ea3cf45f75d49fea81cb951a3e1db95', '0a2b414cf6354e1f9bc0f2d53b2726ac'),
       ('205e74d57e5645d2ae5dd87736b48eb2', '68f245936b794286835293af6b863deb');


CREATE TABLE IF NOT EXISTS "UserObjective"
(
    objective_id uuid                  NOT NULL,
    username     character varying(50) NOT NULL,
    role         character varying(50) NOT NULL,

    PRIMARY KEY (objective_id, username),

    FOREIGN KEY (objective_id)
        REFERENCES "Objective" (objective_id) ON DELETE CASCADE ON UPDATE CASCADE,

    FOREIGN KEY (username)
        REFERENCES "User" (username) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "UserObjective_objective_id" ON "UserObjective" USING btree (objective_id);

CREATE INDEX "UserObjective_owner_id" ON "UserObjective" USING btree (username);

ALTER TABLE "UserObjective"
    ADD CONSTRAINT uo_roles CHECK ( role in ('owner', 'editor', 'visitor') );

INSERT INTO "UserObjective" (objective_id, username, role)
VALUES ('8743486f8def4d50a7b9288c32575c72', 'Qre', 'owner')
     , ('8743486f8def4d50a7b9288c32575c72', 'Mmd', 'editor');


CREATE TABLE IF NOT EXISTS "TeamObjective"
(
    objective_id uuid                  NOT NULL,
    team_id      serial                NOT NULL,
    role         character varying(50) NOT NULL,

    PRIMARY KEY (objective_id, team_id),

    FOREIGN KEY (objective_id)
        REFERENCES "Objective" (objective_id) ON DELETE CASCADE ON UPDATE CASCADE,

    FOREIGN KEY (team_id)
        REFERENCES "Team" (team_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "TeamObjective_objective_id" ON "TeamObjective" USING btree (objective_id);

CREATE INDEX "TeamObjective_owner_id" ON "TeamObjective" USING btree (team_id);

ALTER TABLE "TeamObjective"
    ADD CONSTRAINT to_roles CHECK ( role in ('editor', 'visitor') );

INSERT INTO "TeamObjective" (objective_id, team_id, role)
VALUES ('f991a0a3b83247159405308f517374a2', 1, 'visitor');


CREATE TABLE IF NOT EXISTS "CheckList"
(
    checklist_id serial                NOT NULL PRIMARY KEY,
    task_id      uuid                  NOT NULL,
    name         character varying(50) NOT NULL,

    FOREIGN KEY (task_id)
        REFERENCES "Task" (objective_ptr_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "CheckList_task_id" ON "CheckList" USING btree (task_id);

INSERT INTO "CheckList" (task_id, name)
VALUES ('764ac120eaa746ba834f0a0b14f881a8', 'First checklist');


CREATE TABLE IF NOT EXISTS "CheckItem"
(
    check_item_id serial                NOT NULL PRIMARY KEY,
    checklist_id  serial                NOT NULL,
    name          character varying(50) NOT NULL,
    statement     boolean DEFAULT False,

    FOREIGN KEY (checklist_id)
        REFERENCES "CheckList" (checklist_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "CheckItem_checklist_id" ON "CheckItem" USING btree (checklist_id);

INSERT INTO "CheckItem" (checklist_id, name)
VALUES (1, 'First check_item');


CREATE TABLE IF NOT EXISTS "Alarm"
(
    alarm_datetime timestamp with time zone NOT NULL PRIMARY KEY,
    name           character varying(50)    NOT NULL,
    task_id        uuid                     NOT NULL,

    FOREIGN KEY (task_id)
        REFERENCES "Task" (objective_ptr_id) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "Alarm_task_id" ON "Alarm" USING btree (task_id);

INSERT INTO "Alarm" (alarm_datetime, name, task_id)
VALUES (now() + interval '1 hour', 'First alarm', '764ac120eaa746ba834f0a0b14f881a8');


CREATE TABLE IF NOT EXISTS "Attachment"
(
    attachment_id serial                NOT NULL PRIMARY KEY,
    task_id       uuid                  NOT NULL,
    name          character varying(50) NOT NULL,

    FOREIGN KEY (task_id)
        REFERENCES "Task" (objective_ptr_id)
);

CREATE INDEX "Attachment_task_id" ON "Attachment" USING btree (task_id);

INSERT INTO "Attachment" (name, task_id)
VALUES ('First attachment', '764ac120eaa746ba834f0a0b14f881a8');


CREATE VIEW Check_view AS
(
SELECT CL.name      as list_name,
       CI.name      as item_name,
       CI.statement as done,
       CL.task_id   as task_id
FROM "CheckList" CL
         INNER JOIN "CheckItem" CI on CL.checklist_id = CI.checklist_id
    );

SELECT *
FROM Check_view;


CREATE VIEW Members AS
(
SELECT T.name     as team_name,
       U.username as username,
       U.email    as email,
       T.team_id  as team_id
FROM "Membership" M
         INNER JOIN "User" U on U.username = M.username
         INNER JOIN "Team" T on T.team_id = M.team_id
    );

SELECT *
FROM Members;


CREATE VIEW Task_Checks AS
(
SELECT T.objective_ptr_id as task_id,
       CH.checklist_id    as list_id,
       CI.check_item_id   as item_id,
       CH.name            as listname,
       CI.name            as itemname,
       CI.statement       as done
FROM "Task" T
         INNER JOIN "CheckList" CH on CH.task_id = T.objective_ptr_id
         INNER JOIN "CheckItem" CI on CH.checklist_id = CI.checklist_id
    );

SELECT *
FROM Task_Checks;


CREATE VIEW Task_Subs AS
(
SELECT T1.objective_ptr_id as from_id,
       T2.objective_ptr_id as "to",
       T1.name             as from_name,
       T2.name             as to_name,
       T2.statement        as done
FROM "Task" T1
         INNER JOIN "Task_sub_tasks" Tst on Tst.from_task = T1.objective_ptr_id
         INNER JOIN "Task" T2 on T2.objective_ptr_id = Tst.to_task
    );

SELECT *
FROM Task_Subs;


CREATE VIEW Task_Process AS
(
SELECT from_id                        as frid,
       count(*) filter ( where done ) as done,
       count(*)                       as "all"
FROM Task_Subs
GROUP BY from_id
    );

SELECT *
FROM Task_Process;


CREATE VIEW Calendar_view AS
(
SELECT objective_ptr_id as id,
       name             as name,
       description      as description,
       start_time       as "start",
       end_time         as "end",
       statement        as done

FROM "Task"
    );

SELECT *
FROM Calendar_view;


CREATE VIEW Gratt_view AS
(
SELECT *,
       ("end" - "start")::interval as interval,
       (now() - "start")::interval as until_now
FROM Calendar_view
    );

SELECT *
FROM Gratt_view;


CREATE VIEW Board_view AS
(
SELECT T.*,
       P.done * 1.0 / P."all"                  as process,
       T.until_now * P."all" / (P.done + 0.001) as estimataion,
       A.name                                  as alarm_name,
       A.alarm_datetime                        as datetime,
       C.name                                  as attname,
       C.attachment_id                         as attid
FROM Gratt_view T
         LEFT JOIN "Alarm" A on T.id = A.task_id
         LEFT JOIN Task_process P on P.frid = T.id
         LEFT JOIN "Attachment" C on T.id = C.task_id
    );

SELECT *
FROM Board_view;


SELECT U.username as username,
       Taa.name   as name,
       Lii.name   as list
FROM "User" U
         INNER JOIN "UserCollections" UC ON U.username = UC.username
         INNER JOIN "Workspace" W ON UC.collection_id = W.collection_ptr_id
         INNER JOIN "Space" Sp ON W.collection_ptr_id = Sp.workspace_id
         INNER JOIN "List" Lii ON Sp.collection_ptr_id = Lii.space_id
         INNER JOIN "Task" Taa on Lii.collection_ptr_id = Taa.list_id;


SELECT U.username    as username,
       G.name        as name,
       G.motivations as motivations,
       G.description as description,
       S.done        as done
FROM "User" U
         INNER JOIN "UserObjective" UO on U.username = UO.username
         INNER JOIN "Goal" G on UO.objective_id = G.objective_ptr_id
         INNER JOIN "Statement" S on G.statement_id = S.statement_id;


CREATE VIEW Collection_members AS
(
SELECT collection_id                                        as collection_id,
       array_agg(username) FILTER ( WHERE role = 'owner')   as owners,
       array_agg(username) FILTER ( WHERE role = 'editor')  as editors,
       array_agg(username) FILTER ( WHERE role = 'visitor') as visitors
FROM "UserCollections"
GROUP BY collection_id);

SELECT *
FROM Collection_members;


CREATE OR REPLACE FUNCTION New_Owner_Collections()
    RETURNS TRIGGER AS
$$
BEGIN

    UPDATE "UserCollections" UC
    SET role = 'owner'
    WHERE username = ANY (
        SELECT tmp.members[2]
        FROM (
                 SELECT (CM.owners || CM.editors || CM.visitors) as members
                 FROM "UserCollections" U1,
                      Collection_members CM
                 WHERE U1.username = old.username
                   AND U1.role = 'owner'
                   AND UC.collection_id = CM.collection_id
                   AND U1.collection_id = CM.collection_id
             ) as tmp
    );

    RETURN old;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER change_user_owner_collections
    BEFORE DELETE
    ON "UserCollections"
    FOR EACH ROW
execute procedure New_Owner_Collections();

CREATE OR REPLACE FUNCTION Delete_User_Collections()
    RETURNS TRIGGER AS
$$
BEGIN

    DELETE
    FROM "Collection"
    WHERE collection_id = old.collection_id
      AND NOT EXISTS(
            SELECT *
            FROM "UserCollections" UC
            WHERE UC.collection_id = old.collection_id
              AND UC.role = 'owner'
        );

    RETURN old;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER delete_useless_collections
    AFTER DELETE
    ON "UserCollections"
    FOR EACH ROW
execute procedure Delete_User_Collections();

INSERT INTO "UserCollections" (collection_id, username, role)
VALUES ('205e74d57e5645d2ae5dd87736b48eb2', 'Mmd', 'editor')
     , ('205e74d57e5645d2ae5dd87736b48eb2', 'ELITE', 'editor');


CREATE VIEW Objective_members AS
(
SELECT objective_id                                         as objective_id,
       array_agg(username) FILTER ( WHERE role = 'owner')   as owners,
       array_agg(username) FILTER ( WHERE role = 'editor')  as editors,
       array_agg(username) FILTER ( WHERE role = 'visitor') as visitors
FROM "UserObjective"
GROUP BY objective_id);

SELECT *
FROM Objective_members;


CREATE OR REPLACE FUNCTION New_Owner_Objectives()
    RETURNS TRIGGER AS
$$
BEGIN

    UPDATE "UserObjective" UO
    SET role = 'owner'
    WHERE username = ANY (
        SELECT tmp.members[2]
        FROM (
                 SELECT (OM.owners || OM.editors || OM.visitors) as members
                 FROM "UserObjective" U1,
                      Objective_members OM
                 WHERE U1.username = old.username
                   AND U1.role = 'owner'
                   AND UO.objective_id = OM.objective_id
                   AND U1.objective_id = OM.objective_id
             ) as tmp
    );

    RETURN old;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER change_user_owner_objectives
    BEFORE DELETE
    ON "UserObjective"
    FOR EACH ROW
execute procedure New_Owner_Objectives();

CREATE OR REPLACE FUNCTION Delete_User_Objectives()
    RETURNS TRIGGER AS
$$
BEGIN

    DELETE
    FROM "Objective"
    WHERE "Objective".objective_id = old.objective_id
      AND NOT EXISTS(
            SELECT *
            FROM "UserObjective" UO
            WHERE UO.objective_id = old.objective_id
              AND UO.role = 'owner'
        );

    RETURN old;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER delete_useless_objectives
    AFTER DELETE
    ON "UserObjective"
    FOR EACH ROW
execute procedure Delete_User_Objectives();

INSERT INTO "UserObjective" (objective_id, username, role)
VALUES ('8743486f8def4d50a7b9288c32575c72', 'ELITE', 'visitor');


DELETE
FROM "User"
WHERE username = 'Qre';
