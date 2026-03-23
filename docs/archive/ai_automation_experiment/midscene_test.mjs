#!/usr/bin/env node
/**
 * Midscene Computer Test for react-solar2d Slider
 * Uses AI to control desktop and test Slider
 */

import { agentFromComputer } from '@midscene/computer';

async function testSlider() {
  console.log('🚀 Starting Midscene Computer Test...\n');

  try {
    // Create agent
    const agent = await agentFromComputer({
      aiActionContext: 'You are testing a React Native Slider component in Solar2D Simulator. The Simulator shows an iPhone with three sliders.',
    });

    console.log('✅ Agent created');

    // Take initial screenshot
    console.log('📸 Taking screenshot...');
    await agent.aiAct('take a screenshot');

    // Query current state
    console.log('🔍 Analyzing screen...');
    const info = await agent.aiQuery(`
      What sliders are visible?
      Return: {sliders: [{name: string, value: string, position: {x: number, y: number}}]}
    `);
    console.log('Found sliders:', JSON.stringify(info, null, 2));

    // Drag first slider
    console.log('🖱️ Dragging first slider...');
    await agent.aiAct('drag the first slider thumb to the right by 100 pixels');

    // Wait a moment
    await new Promise(r => setTimeout(r, 1000));

    // Verify change
    console.log('✓ Verifying change...');
    const newValue = await agent.aiQuery('What is the value of the first slider now?');
    console.log('New value:', newValue);

    // Assert success
    await agent.aiAssert('the first slider has moved to the right');
    console.log('✅ Test passed!');

    // Cleanup
    await agent.destroy();

  } catch (error) {
    console.error('❌ Test failed:', error.message);
    process.exit(1);
  }
}

// Run test
testSlider();
