import express from 'express';
import path from 'path';
import dotenv from 'dotenv';
import { GoogleGenAI, ThinkingLevel } from '@google/genai';
import { createServer as createViteServer } from 'vite';

// Load environment variables
dotenv.config();

const app = express();
const PORT = 3000;

app.use(express.json());

// Initialize Gemini SDK lazily
let aiClient: GoogleGenAI | null = null;

function getGeminiClient(): GoogleGenAI {
  if (!aiClient) {
    const apiKey = process.env.GEMINI_API_KEY;
    if (!apiKey) {
      console.warn('Warning: GEMINI_API_KEY is not defined. AI consulting will be unavailable.');
    }
    aiClient = new GoogleGenAI({
      apiKey: apiKey || '',
      httpOptions: {
        headers: {
          'User-Agent': 'aistudio-build',
        },
      },
    });
  }
  return aiClient;
}

// API Routes
app.post('/api/ai/analyze', async (req, res) => {
  try {
    const { prompt, messages = [], categories = [], companies = [], malls = [], employees = [] } = req.body;

    if (!prompt) {
      return res.status(400).json({ error: 'Prompt is required' });
    }

    const ai = getGeminiClient();

    // Prepare contextual business overview
    const contextOverview = `
You are the Masperv Executive AI Advisory Partner, a world-class corporate strategy consultant. 
The owner of "Company Masperv" is viewing their centralized enterprise dashboard and requires high-level strategic reasoning, resource allocation optimization, operational risk assessments, or summaries.

Below is the real-time, consolidated business data from the Masperv Central Dashboard:

--- BUSINESS CATEGORIES ---
${JSON.stringify(categories, null, 2)}

--- COMPANIES MANAGED ---
${JSON.stringify(companies, null, 2)}

--- SHOPPING MALLS OWNED/OPERATED ---
${JSON.stringify(malls, null, 2)}

--- KEY EMPLOYEES & LEADERS ---
${JSON.stringify(employees, null, 2)}

--- END OF DATA ---

Guidelines for your response:
1. Provide a highly professional, sophisticated, and strategic analysis.
2. Address the user's specific request with detailed insights, actionable steps, and clear calculations where applicable.
3. Structure your response beautifully using clear Markdown, lists, and tables.
4. Speak directly to the Masperv owner ("Mr. Masperv" or "Owner") with professional respect and executive tone.
`;

    // Construct contents for Chat or Single Message
    const conversationHistory = messages.map((m: any) => ({
      role: m.role,
      parts: [{ text: m.text }]
    }));

    // Add current prompt
    conversationHistory.push({
      role: 'user',
      parts: [{ text: prompt }]
    });

    console.log(`Sending query to gemini-3.1-pro-preview with ThinkingLevel.HIGH...`);

    const response = await ai.models.generateContent({
      model: 'gemini-3.1-pro-preview',
      contents: conversationHistory,
      config: {
        systemInstruction: contextOverview,
        thinkingConfig: {
          thinkingLevel: ThinkingLevel.HIGH
        }
      }
    });

    // Safely extract text
    const responseText = response.text || "I was unable to formulate a strategic answer at this moment.";
    
    // Attempt to extract any internal thinking process returned in parts
    let thinkingText = '';
    const parts = response.candidates?.[0]?.content?.parts;
    if (parts) {
      for (const part of parts) {
        if ((part as any).thought || (part as any).thinking) {
          thinkingText += (part as any).text || '';
        }
      }
    }

    res.json({
      text: responseText,
      thinking: thinkingText || undefined,
    });

  } catch (error: any) {
    console.error('Error during AI analysis:', error);
    res.status(500).json({
      error: 'Failed to generate strategic analysis.',
      details: error?.message || String(error)
    });
  }
});

// Vite Integration
async function startServer() {
  if (process.env.NODE_ENV !== 'production') {
    const vite = await createViteServer({
      server: { middlewareMode: true },
      appType: 'spa',
    });
    app.use(vite.middlewares);
  } else {
    const distPath = path.join(process.cwd(), 'dist');
    app.use(express.static(distPath));
    app.get('*', (req, res) => {
      res.sendFile(path.join(distPath, 'index.html'));
    });
  }

  app.listen(PORT, '0.0.0.0', () => {
    console.log(`Server running on http://0.0.0.0:${PORT}`);
  });
}

startServer();
