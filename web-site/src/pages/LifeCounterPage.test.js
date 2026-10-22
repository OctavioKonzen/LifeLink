import { describe, expect, test } from 'vitest'
import { rowsFor, seatRows } from './LifeCounterPage'

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

  test('meu lugar na mesa online: os outros em linhas de até 3', () => {
    expect(seatRows(2, 0)).toEqual([[1]])
    expect(seatRows(5, 2)).toEqual([[0, 1, 3], [4]])
    expect(seatRows(6, 5)).toEqual([[0, 1, 2], [3, 4]])
  })
})
