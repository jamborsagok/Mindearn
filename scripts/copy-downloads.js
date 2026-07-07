import { cpSync, mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const rootDir = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const srcDir = path.join(rootDir, 'assets', 'downloads');
const destDir = path.join(rootDir, 'dist', 'assets', 'downloads');

mkdirSync(destDir, { recursive: true });
cpSync(srcDir, destDir, { recursive: true });

console.log(`Copied downloads: ${srcDir} -> ${destDir}`);
