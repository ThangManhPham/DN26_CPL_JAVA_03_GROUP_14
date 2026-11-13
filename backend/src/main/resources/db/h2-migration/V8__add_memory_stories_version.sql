-- V8__add_memory_stories_version.sql
-- Optimistic locking support for memory stories
ALTER TABLE memory_stories ADD COLUMN version BIGINT NOT NULL DEFAULT 0;

