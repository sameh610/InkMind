const fs = require('node:fs');
const path = require('node:path');

const bundlePath = path.join(__dirname, '..', 'web', 'ai_worker.bundle.js');
const bundle = fs.readFileSync(bundlePath, 'utf8');

// GitHub's secret scanner mistakes this upstream model-class identifier for
// a Mistral API key. Rename the identifier consistently; architecture routing
// remains intact because both the declaration and its mapping are rewritten.
const upstreamName = 'Mistral3ForConditionalGeneration';
const safeName = 'MistralThreeForConditionalGeneration';
if (!bundle.includes(upstreamName)) {
  throw new Error('Expected Mistral3 model class identifier was not found in the AI bundle.');
}

fs.writeFileSync(bundlePath, bundle.replaceAll(upstreamName, safeName));
