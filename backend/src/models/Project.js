/**
 * Project Model
 * Database schema for video projects
 */

import { DataTypes } from 'sequelize';
import { sequelize } from '../config/database.js';
import User from './User.js';

const Project = sequelize.define('Project', {
  id: {
    type: DataTypes.UUID,
    defaultValue: DataTypes.UUIDV4,
    primaryKey: true
  },
  userId: {
    type: DataTypes.UUID,
    allowNull: false,
    references: {
      model: User,
      key: 'id'
    }
  },
  name: {
    type: DataTypes.STRING,
    allowNull: false
  },
  description: {
    type: DataTypes.TEXT,
    allowNull: true
  },
  status: {
    type: DataTypes.ENUM('draft', 'analyzing', 'processing', 'rendering', 'completed', 'failed'),
    defaultValue: 'draft'
  },
  originalVideoPath: {
    type: DataTypes.STRING,
    allowNull: true
  },
  outputVideoPath: {
    type: DataTypes.STRING,
    allowNull: true
  },
  analysis: {
    type: DataTypes.JSONB, // Stores AI analysis results
    allowNull: true
  },
  references: {
    type: DataTypes.JSONB, // Stores reference video URLs
    allowNull: true
  },
  aeProjectPath: {
    type: DataTypes.STRING,
    allowNull: true
  },
  progress: {
    type: DataTypes.INTEGER,
    defaultValue: 0,
    validate: {
      min: 0,
      max: 100
    }
  },
  errorMessage: {
    type: DataTypes.TEXT,
    allowNull: true
  }
}, {
  tableName: 'projects',
  timestamps: true,
  indexes: [
    { fields: ['userId'] },
    { fields: ['status'] },
    { fields: ['createdAt'] }
  ]
});

// Associations
User.hasMany(Project, { foreignKey: 'userId', as: 'projects' });
Project.belongsTo(User, { foreignKey: 'userId', as: 'user' });

export default Project;
