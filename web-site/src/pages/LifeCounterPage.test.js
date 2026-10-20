import { describe, expect, test } from 'vitest'
import { rowsFor } from './LifeCounterPage'

describe('divisão da tela do contador', () => {
  test('tela larga: mais jogadores lado a lado', () => {
    expect(rowsFor(2, true)).toEqual([[0, 1]])
    expect(rowsFor(5, true)).toEqual([[0, 1, 2], [3, 4]])
    expect(rowsFor(6, true)).toEqual([[0, 1, 2], [3, 4, 5]])
  })

  test('celular em pé: mais um embaixo do outro', () => {
    expect(rowsFor(2, false)).toEqual([[0], [1]])
    expect(rowsFor(3, false)).toEqual([[0], [1, 2]])
    expect(rowsFor(6, false)).toEqual([[0, 1], [2, 3], [4, 5]])
  })
})
