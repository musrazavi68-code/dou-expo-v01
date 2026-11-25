import sharp from "sharp";
import { mkdir } from "node:fs/promises";
await mkdir("assets",{recursive:true});
await sharp("assets/icon.svg").resize(1024,1024).png().toFile("assets/icon.png");
await sharp("assets/icon.svg").resize(512,512).png().toFile("assets/splash.png");
console.log("Generated Dou Expo launcher assets.");
