-- AI Stack PostgreSQL Initialization Script
-- Creates databases and enables pgvector extension for all services

-- Enable pgvector extension on main database
CREATE EXTENSION IF NOT EXISTS vector;

-- Create additional databases for services
CREATE DATABASE n8n_db;
CREATE DATABASE litellm_db;
CREATE DATABASE openwebui_db;

-- Connect to each database and enable pgvector
\c n8n_db
CREATE EXTENSION IF NOT EXISTS vector;

\c litellm_db
CREATE EXTENSION IF NOT EXISTS vector;

\c openwebui_db
CREATE EXTENSION IF NOT EXISTS vector;
