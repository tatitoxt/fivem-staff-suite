import '@testing-library/jest-dom/vitest';
import { cleanup } from '@testing-library/react';
import { afterEach } from 'vitest';

afterEach(() => cleanup());

// jsdom no implementa scrollTo/scrollIntoView en elementos.
Element.prototype.scrollIntoView ??= function scrollIntoView() {};
